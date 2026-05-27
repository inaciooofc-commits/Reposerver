from run import socketio
import time
from app.modules.antix_panel.monitoring.services import get_system_usage
from app.modules.antix_panel.process_manager.services import get_process_list
from app.modules.antix_panel.docker_manager.services import get_docker_containers

# A dictionary to hold our background tasks
background_tasks = {
    "system_monitor": None
}

def system_monitor_task():
    """A background task that emits system stats every 2 seconds."""
    while True:
        stats = get_system_usage()
        socketio.emit('system_update', stats, namespace='/antix')
        
        procs = get_process_list()
        socketio.emit('process_update', {'processes': procs}, namespace='/antix')

        containers = get_docker_containers()
        socketio.emit('docker_update', {'containers': containers}, namespace='/antix')

        socketio.sleep(2) # Use socketio.sleep for cooperative multitasking

@socketio.on('connect', namespace='/antix')
def on_connect():
    print('Anti X Panel client connected.')
    # Start the background task if it hasn't been started yet
    if background_tasks.get("system_monitor") is None:
        print("Starting background system monitor...")
        task = socketio.start_background_task(system_monitor_task)
        background_tasks["system_monitor"] = task

@socketio.on('request_initial_data', namespace='/antix')
def on_request_initial_data():
    # Immediately send the current data upon request
    stats = get_system_usage()
    socketio.emit('system_update', stats, namespace='/antix')
    procs = get_process_list()
    socketio.emit('process_update', {'processes': procs}, namespace='/antix')
    containers = get_docker_containers()
    socketio.emit('docker_update', {'containers': containers}, namespace='/antix')

@socketio.on('terminal_in', namespace='/antix')
def on_terminal_in(data):
    # This is a placeholder. A real implementation needs a PTY.
    # For now, we'll just echo back.
    command = data.get('data', '')
    # In a real scenario, you'd write this to the PTY of a shell process
    # and the PTY's output would be read and emitted back.
    # For demonstration, we simulate a simple command.
    if command == 'ls\r':
        response = 'file1.txt  file2.py  README.md\r\n$ '
    elif command:
        response = f"command '{(command or "").strip()}' executed (simulation).\r\n$ "
    else:
        response = ""
    socketio.emit('terminal_out', {'data': response}, namespace='/antix')

@socketio.on('disconnect', namespace='/antix')
def on_disconnect():
    print('Anti X Panel client disconnected.')
