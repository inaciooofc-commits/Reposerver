import psutil

def get_system_usage():
    """Returns a dictionary with system usage stats."""
    
    # CPU Usage
    cpu_percent = psutil.cpu_percent(interval=1)
    
    # RAM Usage
    ram = psutil.virtual_memory()
    ram_percent = ram.percent
    
    # Disk Usage
    disk = psutil.disk_usage('/')
    disk_percent = disk.percent
    
    # Network I/O
    net_io = psutil.net_io_counters()
    # A simple way to represent network traffic - you might want a more complex calculation
    net_rx = f"{(net_io.bytes_recv / 1024 / 1024):.2f} MB"
    net_tx = f"{(net_io.bytes_sent / 1024 / 1024):.2f} MB"

    return {
        'cpu': cpu_percent,
        'ram': ram_percent,
        'disk': disk_percent,
        'net_rx': net_rx,
        'net_tx': net_tx
    }
