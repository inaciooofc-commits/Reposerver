
#!/usr/bin/env python3
"""
A modern, rich-powered command-line tool for project management.
"""
import argparse
import subprocess
import sys
import os
from rich.console import Console
from rich.panel import Panel
from rich.spinner import Spinner
from rich.text import Text

# --- Console Setup ---
console = Console()

# --- Base Directory ---
# The directory where this script and other project files are located.
BASE_DIR = os.path.dirname(os.path.abspath(__file__))


def run_command(command, message):
    """Runs a command and shows a spinner."""
    with console.status(f"[bold green]{message}[/]") as status:
        try:
            result = subprocess.run(
                command, 
                shell=True, 
                check=True, 
                capture_output=True, 
                text=True,
                cwd=BASE_DIR  # Ensure commands run in the script's directory
            )
            console.print(f"[green]✓ Success:[/] {message}")
            return result
        except subprocess.CalledProcessError as e:
            console.print(f"[bold red]✗ Error:[/] {e.stderr}")
            sys.exit(1)

def install_command():
    """Installs the 'clatt' command to /usr/local/bin."""
    console.print(Panel.fit(
        Text("Installing 'clatt' Command", justify="center"),
        title="[bold cyan]Installation[/]",
        border_style="green"
    ))

    if os.geteuid() != 0:
        console.print("[bold red]Error:[/] This command must be run with root privileges.")
        console.print("Please try again using 'sudo python3 clatt.py install'.")
        sys.exit(1)

    script_path = os.path.join(BASE_DIR, 'clatt.py')
    install_path = "/usr/local/bin/clatt"
    
    console.print(f"Creating symbolic link from [cyan]{script_path}[/] to [cyan]{install_path}[/]")
    run_command(f"ln -sf {script_path} {install_path}", "Linking script")
    run_command(f"chmod +x {install_path}", "Making script executable")

    console.print("\n[bold green]Installation complete![/] You can now run 'clatt' from anywhere.")

def update_command():
    """Runs the project updater script."""
    console.print(Panel.fit(
        Text("Checking for Updates", justify="center"),
        title="[bold cyan]Updater[/]",
        border_style="green"
    ))
    updater_script = os.path.join(BASE_DIR, 'updater.py')
    run_command(f"python3 {updater_script}", "Running updater")

def list_api_command():
    """Lists all API routes using the dedicated script."""
    list_routes_script = os.path.join(BASE_DIR, 'list_routes.py')
    # No spinner here, as the script has its own rich output
    subprocess.run(["python3", list_routes_script], cwd=BASE_DIR)


def main():
    """Main function to parse arguments and execute commands."""
    parser = argparse.ArgumentParser(
        description=Text.from_markup("[bold cyan]CLATT[/] - A tool for managing your project.")
    )
    subparsers = parser.add_subparsers(dest='command', help='Available commands')

    # Define subcommands
    subparsers.add_parser('install', help='Install clatt globally.')
    subparsers.add_parser('update', help='Check for project updates.')
    subparsers.add_parser('list-api', help='List all available API routes.')

    args = parser.parse_args()

    if args.command == 'install':
        install_command()
    elif args.command == 'update':
        update_command()
    elif args.command == 'list-api':
        list_api_command()
    else:
        # Default action: show help
        parser.print_help()

if __name__ == "__main__":
    main()
