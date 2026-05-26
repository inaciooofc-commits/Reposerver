sudo 
#!/usr/bin/env python3
"""
Lists all registered Flask routes in a visually appealing table.
"""
import sys
import os

# --- Rich and Console Setup ---
from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich.text import Text

console = Console()

# --- App Import ---
# Adjust the path to import the app from the parent directory
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    from server import app
except ImportError as e:
    console.print(f"[bold red]Error importing the Flask app:[/] {e}")
    console.print("Please ensure that [cyan]server.py[/] exists and doesn't have import errors.")
    sys.exit(1)

def get_routes():
    """Extracts and organizes routes from the Flask app."""
    routes = []
    for rule in sorted(app.url_map.iter_rules(), key=lambda r: r.rule):
        if rule.endpoint in ('static', 'send_file'):
            continue

        methods = sorted(rule.methods - {'HEAD', 'OPTIONS'})
        view_func = app.view_functions[rule.endpoint]
        doc = view_func.__doc__ or ""
        description = doc.strip().split('\n')[0]

        routes.append({
            "endpoint": rule.rule,
            "methods": ", ".join(methods),
            "description": description
        })
    return routes

def main():
    """Creates and prints a rich table of API routes."""
    console.print(
        Panel(
            Text("API Route Information", justify="center", style="bold cyan"),
            border_style="green"
        )
    )

    routes = get_routes()
    
    if not routes:
        console.print("[yellow]No application routes were found.[/]")
        return

    table = Table(title="Available API Endpoints", border_style="magenta")
    table.add_column("Endpoint", style="cyan", no_wrap=True)
    table.add_column("Methods", style="green")
    table.add_column("Description", style="yellow")

    for route in routes:
        table.add_row(
            route["endpoint"],
            route["methods"],
            route["description"]
        )

    console.print(table)

if __name__ == '__main__':
    main()
