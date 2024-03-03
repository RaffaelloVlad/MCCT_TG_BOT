# server/app.py
from flask import Flask, request, jsonify

app = Flask(__name__)

# Dummy storage for the configuration
# In a real application, consider using a more persistent storage solution
config_storage = {}
last_command = {"action": "startMining"}

@app.route('/update-config', methods=['POST'])
def update_config():
    global config_storage
    new_config = request.json
    # Validate new_config here (for example, check for required fields)
    config_storage = new_config
    return jsonify({"status": "success", "message": "Configuration updated successfully."})


@app.route('/get-config', methods=['GET'])
def get_config():
    print(config_storage)
    return jsonify(config_storage)


@app.route('/get-command', methods=['GET', 'POST'])
def get_command():
    global last_command
    if request.method == 'POST':
        # Update the command based on received data
        command_data = request.json
        last_command = command_data
        print(last_command)
        return jsonify({"status": "success", "message": "Command updated successfully."})
    else:  # GET request
        return jsonify(last_command)


if __name__ == "__main__":
    app.run(debug=True, use_reloader=False)