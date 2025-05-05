import random
import json
import threading
import time
from collections import OrderedDict
from flask import Flask, Response, jsonify # https://github.com/pallets/flask

app = Flask(__name__)
initialConnectionString = "Whatever you want, just make it the same on Swift"
currentConnectionString = initialConnectionString
lastRequestTime = time.time()
lock = threading.Lock()

def resetKeyInactive():
    global currentConnectionString, lastRequestTime
    while True:
        time.sleep(5)
        with lock:
            if time.time() - lastRequestTime >= 5:
                currentConnectionString = initialConnectionString

def generateNewKey():
    return ''.join(random.choices('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789', k=64))

@app.route('/verify', methods=['GET'])
def verifyConnection():
    global currentConnectionString, lastRequestTime
    newConnectionString = generateNewKey()
    
    with lock:
        lastRequestTime = time.time()
        response = {
            "connection_string": f"{currentConnectionString},{newConnectionString}"
        }
        currentConnectionString = newConnectionString
    
    return jsonify(response)

def readVehicleData():
    try:
        with open("newestCapture.json", "r") as f:
            return json.load(f, object_pairs_hook=OrderedDict)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        return "ALPR Device powered off, data purged"

@app.route('/vehicle', methods=['GET'])
def getLatestVehicle():
    global lastRequestTime
    with lock:
        lastRequestTime = time.time()
    vehicleData = readVehicleData()
    jsonData = json.dumps(vehicleData, indent=4, sort_keys=False)
    return Response(jsonData, mimetype='application/json')

def runFlask():
    app.run(
        host="0.0.0.0",
        port=5000,
        ssl_context=(cert_file, key_file) #if using createCert.sh, this'll be MobileANPR.local.crt + MobileANPR.local.key
    )


if __name__ == '__main__':
    threading.Thread(target=resetKeyInactive, daemon=True).start()
    runFlask()
