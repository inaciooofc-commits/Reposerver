import psutil

def get_process_list(limit=50):
    """Returns a list of running processes."""
    processes = []
    for proc in psutil.process_iter(['pid', 'name', 'username', 'cpu_percent', 'memory_info']):
        try:
            pinfo = proc.info
            processes.append({
                'pid': pinfo['pid'],
                'name': pinfo['name'],
                'username': pinfo['username'],
                'cpu_percent': pinfo['cpu_percent'],
                'memory_mb': pinfo['memory_info'].rss / (1024 * 1024) # RSS in MB
            })
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            pass
    # Sort by memory usage and return top processes
    return sorted(processes, key=lambda p: p['memory_mb'], reverse=True)[:limit]
