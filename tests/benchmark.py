#!/usr/bin/env python3

import asyncio
import aiohttp
import time
import statistics
import psutil
import argparse
import sys
import signal
from typing import List, Dict, Optional
from dataclasses import dataclass
import json

@dataclass
class RequestResult:
    response_time: float
    status_code: int
    content_length: int
    error: Optional[str] = None

@dataclass
class BenchmarkConfig:
    url: str
    total_requests: int
    concurrent_connections: int
    duration_seconds: Optional[int] = None
    warmup_requests: int = 10
    timeout: float = 10.0
    server_pid: Optional[int] = None

class ServerMonitor:
    def __init__(self, pid: Optional[int] = None):
        self.pid = pid
        self.process = None
        self.cpu_samples = []
        self.memory_samples = []
        self.monitoring = False
        
    def start_monitoring(self):
        if self.pid:
            try:
                self.process = psutil.Process(self.pid)
                self.monitoring = True
                print(f"📊 Monitoring server process {self.pid}")
            except psutil.NoSuchProcess:
                print(f"⚠️  Process {self.pid} not found, skipping resource monitoring")
    
    async def collect_sample(self):
        if not self.monitoring or not self.process:
            return
            
        try:
            cpu_percent = self.process.cpu_percent()
            memory_info = self.process.memory_info()
            
            self.cpu_samples.append(cpu_percent)
            self.memory_samples.append({
                'rss': memory_info.rss,  # Resident Set Size (physical memory)
                'vms': memory_info.vms,  # Virtual Memory Size
            })
        except psutil.NoSuchProcess:
            self.monitoring = False
            print("⚠️  Server process died during monitoring")

class HTTPBenchmark:
    def __init__(self, config: BenchmarkConfig):
        self.config = config
        self.results: List[RequestResult] = []
        self.monitor = ServerMonitor(config.server_pid)
        self.start_time = 0
        self.end_time = 0
        
    async def make_request(self, session: aiohttp.ClientSession) -> RequestResult:
        start_time = time.time()
        
        try:
            async with session.get(
                self.config.url,
                timeout=aiohttp.ClientTimeout(total=self.config.timeout)
            ) as response:
                content = await response.read()
                end_time = time.time()
                
                return RequestResult(
                    response_time=end_time - start_time,
                    status_code=response.status,
                    content_length=len(content)
                )
                
        except Exception as e:
            end_time = time.time()
            return RequestResult(
                response_time=end_time - start_time,
                status_code=0,
                content_length=0,
                error=str(e)
            )
    
    async def warmup(self):
        print(f"🔥 Warming up with {self.config.warmup_requests} requests...")
        
        async with aiohttp.ClientSession() as session:
            tasks = []
            for _ in range(self.config.warmup_requests):
                tasks.append(self.make_request(session))
            
            await asyncio.gather(*tasks)
        
        print("✅ Warmup complete")
    
    async def run_benchmark(self):
        print(f"🚀 Starting benchmark:")
        print(f"   Target: {self.config.url}")
        print(f"   Requests: {self.config.total_requests}")
        print(f"   Concurrency: {self.config.concurrent_connections}")
        print()
        
        # Start server monitoring
        self.monitor.start_monitoring()
        
        # Create semaphore to limit concurrency
        semaphore = asyncio.Semaphore(self.config.concurrent_connections)
        
        async def bounded_request(session):
            async with semaphore:
                result = await self.make_request(session)
                self.results.append(result)
                # Collect server stats periodically
                if len(self.results) % 100 == 0:
                    await self.monitor.collect_sample()
                return result
        
        # Run the actual benchmark
        self.start_time = time.time()
        
        async with aiohttp.ClientSession() as session:
            tasks = []
            for i in range(self.config.total_requests):
                tasks.append(bounded_request(session))
                
                # Progress indicator
                if (i + 1) % 1000 == 0:
                    print(f"📈 Queued {i + 1}/{self.config.total_requests} requests")
            
            print("⏳ Executing requests...")
            self.results = await asyncio.gather(*tasks)
        
        self.end_time = time.time()
        await self.monitor.collect_sample()  # Final sample
    
    def analyze_results(self) -> Dict:
        successful_results = [r for r in self.results if r.error is None and r.status_code == 200]
        failed_results = [r for r in self.results if r.error is not None or r.status_code != 200]
        
        if not successful_results:
            print("❌ No successful requests!")
            return {}
        
        response_times = [r.response_time for r in successful_results]
        total_duration = self.end_time - self.start_time
        
        # Response time statistics
        stats = {
            'total_requests': len(self.results),
            'successful_requests': len(successful_results),
            'failed_requests': len(failed_results),
            'success_rate': len(successful_results) / len(self.results) * 100,
            
            'total_duration_seconds': total_duration,
            'requests_per_second': len(successful_results) / total_duration,
            
            'response_time_stats': {
                'mean_ms': statistics.mean(response_times) * 1000,
                'median_ms': statistics.median(response_times) * 1000,
                'min_ms': min(response_times) * 1000,
                'max_ms': max(response_times) * 1000,
                'std_dev_ms': statistics.stdev(response_times) * 1000 if len(response_times) > 1 else 0,
            },
            
            'percentiles_ms': {
                'p50': statistics.quantiles(response_times, n=100)[49] * 1000 if response_times else 0,
                'p90': statistics.quantiles(response_times, n=100)[89] * 1000 if response_times else 0,
                'p95': statistics.quantiles(response_times, n=100)[94] * 1000 if response_times else 0,
                'p99': statistics.quantiles(response_times, n=100)[98] * 1000 if response_times else 0,
            }
        }
        
        # Server resource usage
        if self.monitor.cpu_samples:
            stats['server_resources'] = {
                'cpu_usage': {
                    'mean_percent': statistics.mean(self.monitor.cpu_samples),
                    'max_percent': max(self.monitor.cpu_samples),
                    'samples': len(self.monitor.cpu_samples)
                },
                'memory_usage': {
                    'mean_rss_mb': statistics.mean([s['rss'] for s in self.monitor.memory_samples]) / 1024 / 1024,
                    'max_rss_mb': max([s['rss'] for s in self.monitor.memory_samples]) / 1024 / 1024,
                    'mean_vms_mb': statistics.mean([s['vms'] for s in self.monitor.memory_samples]) / 1024 / 1024,
                    'max_vms_mb': max([s['vms'] for s in self.monitor.memory_samples]) / 1024 / 1024,
                }
            }
        
        # Error breakdown
        if failed_results:
            error_types = {}
            status_codes = {}
            
            for result in failed_results:
                if result.error:
                    error_type = type(result.error).__name__ if hasattr(result.error, '__class__') else str(result.error)
                    error_types[error_type] = error_types.get(error_type, 0) + 1
                else:
                    status_codes[result.status_code] = status_codes.get(result.status_code, 0) + 1
            
            stats['errors'] = {
                'by_type': error_types,
                'by_status_code': status_codes
            }
        
        return stats
    
    def print_results(self, stats: Dict):
        print("\n" + "="*60)
        print("📊 BENCHMARK RESULTS")
        print("="*60)
        
        print(f"🎯 Requests: {stats['successful_requests']}/{stats['total_requests']} "
              f"({stats['success_rate']:.1f}% success)")
        print(f"⏱️  Duration: {stats['total_duration_seconds']:.2f}s")
        print(f"🚀 Throughput: {stats['requests_per_second']:.1f} req/sec")
        
        print(f"\n📈 Response Times:")
        rt = stats['response_time_stats']
        print(f"   Mean:    {rt['mean_ms']:.2f}ms")
        print(f"   Median:  {rt['median_ms']:.2f}ms") 
        print(f"   Min:     {rt['min_ms']:.2f}ms")
        print(f"   Max:     {rt['max_ms']:.2f}ms")
        print(f"   Std Dev: {rt['std_dev_ms']:.2f}ms")
        
        print(f"\n📊 Percentiles:")
        p = stats['percentiles_ms']
        print(f"   50th: {p['p50']:.2f}ms")
        print(f"   90th: {p['p90']:.2f}ms")
        print(f"   95th: {p['p95']:.2f}ms")
        print(f"   99th: {p['p99']:.2f}ms")
        
        if 'server_resources' in stats:
            print(f"\n💻 Server Resources:")
            cpu = stats['server_resources']['cpu_usage']
            mem = stats['server_resources']['memory_usage']
            print(f"   CPU:    {cpu['mean_percent']:.1f}% avg, {cpu['max_percent']:.1f}% peak")
            print(f"   Memory: {mem['mean_rss_mb']:.1f}MB avg, {mem['max_rss_mb']:.1f}MB peak (RSS)")
        
        if 'errors' in stats and stats['failed_requests'] > 0:
            print(f"\n❌ Errors ({stats['failed_requests']} total):")
            if 'by_type' in stats['errors']:
                for error_type, count in stats['errors']['by_type'].items():
                    print(f"   {error_type}: {count}")
            if 'by_status_code' in stats['errors']:
                for status_code, count in stats['errors']['by_status_code'].items():
                    print(f"   HTTP {status_code}: {count}")

async def main():
    parser = argparse.ArgumentParser(description='Benchmark HTTP server performance')
    parser.add_argument('url', help='URL to benchmark (e.g., http://localhost:8080)')
    parser.add_argument('-n', '--requests', type=int, default=1000, help='Total requests (default: 1000)')
    parser.add_argument('-c', '--concurrency', type=int, default=10, help='Concurrent connections (default: 10)')
    parser.add_argument('-w', '--warmup', type=int, default=10, help='Warmup requests (default: 10)')
    parser.add_argument('-t', '--timeout', type=float, default=10.0, help='Request timeout seconds (default: 10)')
    parser.add_argument('-p', '--pid', type=int, help='Server process ID for resource monitoring')
    parser.add_argument('--json', help='Save results to JSON file')
    parser.add_argument('--no-warmup', action='store_true', help='Skip warmup phase')
    
    args = parser.parse_args()
    
    config = BenchmarkConfig(
        url=args.url,
        total_requests=args.requests,
        concurrent_connections=args.concurrency,
        warmup_requests=0 if args.no_warmup else args.warmup,
        timeout=args.timeout,
        server_pid=args.pid
    )
    
    benchmark = HTTPBenchmark(config)
    
    try:
        # Warmup phase
        if config.warmup_requests > 0:
            await benchmark.warmup()
        
        # Main benchmark
        await benchmark.run_benchmark()
        
        # Analyze and display results
        stats = benchmark.analyze_results()
        benchmark.print_results(stats)
        
        # Save JSON if requested
        if args.json:
            with open(args.json, 'w') as f:
                json.dump(stats, f, indent=2)
            print(f"\n💾 Results saved to {args.json}")
        
    except KeyboardInterrupt:
        print("\n⚠️  Benchmark interrupted")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Benchmark failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())
