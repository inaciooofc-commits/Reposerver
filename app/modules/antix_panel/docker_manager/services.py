import docker

def get_docker_containers():
    """Returns a list of running Docker containers."""
    try:
        client = docker.from_env()
        containers = client.containers.list(all=True)
    except Exception:
        # If Docker is not running or installed, return empty list
        return []

    container_list = []
    for container in containers:
        ports = '-'
        if container.ports:
            # Create a more readable port mapping string
            port_mappings = []
            for private_port, host_ports in container.ports.items():
                if host_ports:
                    host_port_str = ", ".join([f"{p['HostIp']}:{p['HostPort']}" for p in host_ports])
                    port_mappings.append(f"{private_port}/tcp -> {host_port_str}")
            ports = " | ".join(port_mappings)

        container_list.append({
            'id': container.short_id,
            'image': ", ".join(container.image.tags),
            'status': container.status,
            'name': container.name,
            'ports': ports
        })
    return container_list
