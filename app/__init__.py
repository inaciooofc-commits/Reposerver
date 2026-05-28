from flask import Flask
from .modules.antix_panel.routes import antix_panel_bp
from .modules.dashboard.routes import dashboard_bp

def create_app():
    app = Flask(__name__)

    # Register Blueprints
    app.register_blueprint(antix_panel_bp)
    app.register_blueprint(dashboard_bp)

    return app
