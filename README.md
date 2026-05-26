# Anime Pulse Music Server

Welcome to the Anime Pulse Music Server, a dedicated web-based control panel for managing a shared music playback experience, primarily designed for anime and gaming music enthusiasts.

This project provides a complete Flask-based web application that allows users to log in, queue up music from YouTube, and listen to a synchronized audio stream. It features an administrative backend for user and system management, credit-based playback control, and a sleek, modern interface.

## Features

- **Web-based Interface**: Control music playback from any browser.
- **User Authentication**: Secure login system with roles (user and admin).
- **Google OAuth Integration**: Optional one-click login via Google.
- **YouTube Integration**: Play any public YouTube video as an audio track.
- **Shared Queue**: All users listen to the same music queue.
- **Credit System**: Users spend credits to queue music.
- **Admin Panel**: Comprehensive dashboard for managing users, configuration, and monitoring the system.
- **Modular Architecture**: Built with Flask Blueprints for clean, organized, and extensible code.
- **Customizable Themes**: Easily change the panel's appearance via the admin settings.
- **Git Integration**: Admins can pull the latest updates directly from the web interface.

## Project Structure

The project is organized into a modular structure for better maintainability:

```
/project-root
|-- central.log
|-- server.log
|-- config.json
|-- users.json
|-- payments.json
|-- ip_log.json
|-- status.json
|-- server.py            # Main application entry point
|-- config.py            # Centralized configuration management
|-- utils.py             # Shared utility functions
|-- routes/              # Flask Blueprints for modular routing
|   |-- __init__.py
|   |-- auth.py          # Authentication routes (login, logout, Google OAuth)
|   |-- dashboard.py     # User dashboard routes
|   |-- admin.py         # Admin panel routes and actions
|   |-- api.py           # API endpoints (play, buy credits, etc.)
|   |-- decorators.py    # Shared decorators (login_required, admin_required)
|-- static/              # Static assets (CSS, JS, images)
|   |-- css/
|   |-- js/
|   |-- img/
|-- templates/           # HTML templates
|   |-- admin.html
|   |-- dashboard.html
|   |-- login.html
|-- README.md            # This file
|-- COMMANDS.md          # Description of available bot commands
```

## Setup and Installation

1.  **Clone the Repository**:
    ```bash
    git clone <your-repository-url>
    cd <repository-folder>
    ```

2.  **Install Dependencies**:
    It is highly recommended to use a virtual environment.
    ```bash
    python3 -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt
    ```

3.  **Install `mpv`**:
    The server relies on the `mpv` command-line media player for audio playback.
    - **On Debian/Ubuntu**: `sudo apt-get install mpv`
    - **On other systems**: Follow the instructions on the [mpv website](https://mpv.io/installation/).

4.  **Configure the Server**:
    - Create a `config.json` file in the root directory.
    - At a minimum, you must set a `secret_key` for session management.
    - See `config.py` for all available configuration options that can be set in `config.json` (e.g., Google API keys, Cloudflare settings, etc.).

5.  **Run the Server**:
    ```bash
    python server.py
    ```
    The server will be available at `http://0.0.0.0:5000` by default.

## First-time Admin Setup

- On the first run, no admin user exists.
- You will need to manually create an admin user in the `users.json` file.
- Set the user's `role` to `"admin"` and ensure the username starts with `"admin@"` to comply with the default validation rules.

## Contributing

Contributions are welcome! If you find a bug or have a suggestion for a new feature, please open an issue or submit a pull request.
