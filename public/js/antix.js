document.addEventListener('DOMContentLoaded', function () {
    const socket = io('/antix'); // Namespace for our panel

    // ==========
    //  Terminal
    // ==========
    const term = new Terminal({
        cursorBlink: true,
        theme: {
            background: '#000000',
            foreground: '#00ff00',
            cursor: '#00ff00'
        }
    });
    const terminalContainer = document.getElementById('terminal-container');
    term.open(terminalContainer);

    term.onData(data => {
        socket.emit('terminal_in', { data: data });
    });

    socket.on('terminal_out', function (msg) {
        if (msg.data) {
            term.write(msg.data);
        }
    });

    term.write('Welcome to ANTI X Live Terminal!\r\n');
    term.write('$ ');

    // ===============
    // System Monitor
    // ===============
    socket.on('system_update', function(data) {
        document.querySelector('#cpu-usage span').textContent = data.cpu;
        document.querySelector('#ram-usage span').textContent = data.ram;
        document.querySelector('#disk-usage span').textContent = data.disk;
        document.querySelector('#network-traffic span').textContent = `RX: ${data.net_rx} | TX: ${data.net_tx}`;
    });

    // =================
    // Process Manager
    // =================
    socket.on('process_update', function(data) {
        const tbody = document.getElementById('process-list');
        tbody.innerHTML = ''; // Clear existing data
        data.processes.forEach(proc => {
            const row = `<tr>
                <td>${proc.pid}</td>
                <td>${proc.name}</td>
                <td>${proc.cpu_percent}%</td>
                <td>${(proc.memory_mb).toFixed(2)} MB</td>
                <td>${proc.username}</td>
            </tr>`;
            tbody.innerHTML += row;
        });
    });

    // ================
    //  Docker Manager
    // ================
    socket.on('docker_update', function(data) {
        const tbody = document.getElementById('docker-containers');
        tbody.innerHTML = ''; // Clear existing data
        data.containers.forEach(container => {
            const row = `<tr>
                <td>${container.id}</td>
                <td>${container.image}</td>
                <td>${container.status}</td>
                <td>${container.ports}</td>
                <td>${container.name}</td>
            </tr>`;
            tbody.innerHTML += row;
        });
    });

    // General connection events
    socket.on('connect', () => {
        console.log('Connected to Anti X WebSocket bridge.');
        // Request initial data after connection
        socket.emit('request_initial_data');
    });

    socket.on('disconnect', () => {
        console.log('Disconnected from WebSocket bridge.');
    });
});
