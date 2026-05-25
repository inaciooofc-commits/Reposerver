import json
import os
import time

from rich.console import Console
from rich.layout import Layout
from rich.live import Live
from rich.panel import Panel
from rich.table import Table

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
STATUS_FILE = os.path.join(BASE_DIR, 'status.json')
LOG_FILE = os.path.join(BASE_DIR, 'server.log')

console = Console()


def load_json(path, default):
    if not os.path.exists(path):
        return default
    try:
        with open(path, 'r', encoding='utf-8') as handle:
            return json.load(handle)
    except Exception:
        return default


def render_layout(status, logs):
    layout = Layout()
    layout.split_column(
        Layout(name='header', size=5),
        Layout(name='body', ratio=3),
        Layout(name='footer', size=8),
    )
    layout['body'].split_row(Layout(name='left'), Layout(name='right'))

    header = Panel(
        f"[bold cyan]Anime Pulse Monitor[/bold cyan]\nStatus: [bold green]{status.get('current', {}).get('status') or 'idle'}[/bold green] | Queue: [bold magenta]{len(status.get('queue', []))}[/bold magenta] | Active: [bold yellow]{len(status.get('active_users', []))}[/bold yellow]",
        title='Monitor de Prompt', border_style='bright_magenta', padding=(1, 2),
    )

    current = status.get('current')
    if current:
        current_text = f"[bold]{current.get('title')}[/bold]\nSolicitado por: {current.get('requestor')}\nStatus: {current.get('status')}"
    else:
        current_text = '[bold]Nenhuma faixa em reprodução[/bold]\nUse o painel web para adicionar músicas.'
    layout['body']['left'].update(Panel(current_text, title='Reprodução Atual', border_style='cyan'))

    queue_table = Table(show_header=True, header_style='bold magenta')
    queue_table.add_column('Fila', style='white')
    queue_table.add_column('Solicitado por', style='bright_cyan')
    for item in status.get('queue', [])[:8]:
        queue_table.add_row(item.get('title', '---'), item.get('requestor', '---'))
    if not status.get('queue'):
        queue_table.add_row('Fila vazia', '-')

    layout['body']['right'].update(Panel(queue_table, title='Próximas músicas', border_style='green'))

    events = '\n'.join(status.get('recent_events', [])[:6]) or 'Sem eventos recentes.'
    layout['footer'].split_row(Layout(name='events'), Layout(name='logs'))
    layout['footer']['events'].update(Panel(events, title='Eventos Recentes', border_style='bright_blue'))

    log_text = '\n'.join(logs[-8:]) or 'Sem logs ainda.'
    layout['footer']['logs'].update(Panel(log_text, title='Logs de servidor', border_style='bright_black'))

    layout['header'].update(Panel('[bold]Aperte Ctrl+C para sair[/bold]\nAtualizando a cada segundo', border_style='bright_white'))
    return layout


def main():
    with Live(render_layout(load_json(STATUS_FILE, {}), []), refresh_per_second=1, console=console) as live:
        while True:
            status = load_json(STATUS_FILE, {})
            if os.path.exists(LOG_FILE):
                with open(LOG_FILE, 'r', encoding='utf-8') as handle:
                    logs = handle.read().splitlines()
            else:
                logs = []
            live.update(render_layout(status, logs))
            time.sleep(1)


if __name__ == '__main__':
    main()
