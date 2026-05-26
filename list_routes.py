
#!/usr/bin/env python3
"""
Lists all registered Flask routes in the application.
"""
import sys
import os

# Adjust the path to import the app from the parent directory
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    from server import app
except ImportError as e:
    print(f"Error importing the Flask app: {e}")
    print("Please ensure that server.py exists and doesn't have import errors.")
    sys.exit(1)

def main():
    """Prints all registered routes, their methods, and descriptions."""
    print("Listing all available API routes:")
    rules = sorted(app.url_map.iter_rules(), key=lambda r: r.rule)
    
    for rule in rules:
        # Exclude static and other internal routes
        if rule.endpoint in ('static', 'send_file'):
            continue
            
        methods = ', '.join(sorted(rule.methods - {'HEAD', 'OPTIONS'}))
        
        # Get the function object to access its docstring
        view_func = app.view_functions[rule.endpoint]
        doc = view_func.__doc__ or ""
        description = doc.strip().split('\n')[0]
        
        print(f"\n- Endpoint: {rule.rule}")
        print(f"  Methods: {methods}")
        if description:
            print(f"  Description: {description}")

if __name__ == '__main__':
    main()
