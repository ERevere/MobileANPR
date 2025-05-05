from bs4 import BeautifulSoup # https://pypi.org/project/beautifulsoup4/
from fast_alpr import ALPR # https://github.com/ankandrew/fast-alpr
import os
import tensorflow # https://github.com/tensorflow
import numpy # https://github.com/numpy/numpy
import requests
import cv2 # https://github.com/opencv/opencv
import json
import re
import base64

# MobileNetV2 - https://github.com/pytorch/vision/blob/main/torchvision/models/mobilenetv2.py

carDetails = {}

model = None

def init_model():
    global model
    if model is None:
        model = tensorflow.keras.applications.MobileNetV2(weights='imagenet')


def encodeImage():
    with open("annotatedResult.png", "rb") as image_file:
        image_data = image_file.read()
        encoded_image = base64.b64encode(image_data).decode('utf-8')
    return encoded_image

def saveVehicleData(carDetails):
    with open("newestCapture.json", "w") as f:
        json.dump(carDetails, f, indent=4, sort_keys=False)

def preprocessImage(image):
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    enhanced = cv2.equalizeHist(gray)
    return enhanced

def handleNewImage():
    global carDetails
    alreadyMatched = False
    allVehicleTypes = [
        "sedan", "ambulance", "van", "coupe", "convertible", "hatchback", "suv", "truck",
        "pickup", "minivan", "motorcycle", "bus", "firetruck", "police car", "taxi", "tanker",
        "tractor", "trailer", "limousine", "jeep", "sports car", "delivery van", "garbage truck",
        "tow truck", "caravan", "off-roader", "roadster", "box truck", "cement mixer",
        "snowplow", "armored truck", "golf cart", "quad bike", "forklift", "bulldozer",
        "excavator", "crane", "dump truck", "mobile home", "hearse", "racing car",
        "utility vehicle", "military vehicle", "segway", "rickshaw", "bicycle", "tricycle",
        "hoverboard", "go-kart", "police van"
    ]
    init_model()
    image = cv2.imread('newestImage.jpg')
    processedImage = preprocessImage(image)
    imageRGB = cv2.cvtColor(processedImage, cv2.COLOR_GRAY2RGB)
    imageResized = cv2.resize(imageRGB, (224, 224))
    imageReady = numpy.expand_dims(imageResized, axis=0)
    imageReady = tensorflow.keras.applications.mobilenet_v2.preprocess_input(imageReady)

    predictions = model.predict(imageReady)
    decodedPredictions = tensorflow.keras.applications.mobilenet_v2.decode_predictions(predictions, top=5)[0]

    for imagenetId, label, score in decodedPredictions:
        for vehicleType in allVehicleTypes:
            if label == vehicleType and not alreadyMatched:
                print(f"Image likely contains: {label} with confidence score: {score}")
                alreadyMatched = True
                h, w, _ = image.shape
                height = image[int(h * 0.433): h, :]
                left = int(w * (0.5 - 0.2 / 2))
                right = int(w * (0.5 + 0.2 / 2))
                croppedImage = height[:, left:right]
                cv2.imwrite("reg.jpg", croppedImage)

                carDetails = getRegOfVehicle(carDetails)
                if carDetails:
                    for key, value in carDetails.items():
                        print(f"{key}: {value}")
                    carDetails['vehicleImage'] = encodeImage()
                saveVehicleData(carDetails)
                break

def cleanPlateText(text):
    return re.sub(r'[^A-Za-z0-9]', '', text)

def getRegOfVehicle(currentCarDetails):
    alpr = ALPR(
        detector_model="yolo-v9-t-384-license-plate-end2end",
        ocr_model="global-plates-mobile-vit-v2-model",
    )

    sourceImage = "newestImage.jpg"
    frame = cv2.imread(sourceImage)
    annotatedImage = alpr.draw_predictions(frame)
    outputImage = "annotatedResult.png"
    cv2.imwrite(outputImage, annotatedImage)

    alprResults = alpr.predict(sourceImage)

    for result in alprResults:
        plate = result.ocr.text
        detectionConfidence = result.detection.confidence
        ocrConfidence = result.ocr.confidence

        if ocrConfidence > 1:
            ocrConfidence = ocrConfidence / 1_000_000

        avg_conf = (detectionConfidence + ocrConfidence) / 2

        if avg_conf < 0.4:
            print(f"Low average confidence ({avg_conf:.2f}), rescanning")
            return currentCarDetails


        plate = cleanPlateText(plate)

        if not (3 <= len(plate) <= 8):
            continue

        manxPatterns = [
            r"^[A-Z]{3}\d{3}[A-Z]{1}$",   # XMN000X
            r"^[A-Z]{3}\d{4}$",           # MAN0000
            r"^MN\d{4}$",                 # MN0000
            r"^\d{4}MN$",                 # 0000MN
            r"^XMN\d{4}$"                 # XMN0000
        ]
        ukPatterns = [
            r"^[A-Z]{2}\d{2}\s?[A-Z]{3}$",        # XX00 XXX format
            r"^[A-Z]{1,2}\d{1,4}\s?[A-Z]{1,3}$"   # Custom plates such as A123 XYZ
        ]

        for pattern in manxPatterns:
            if re.match(pattern, plate):
                return getManxDetails(plate)

        for pattern in ukPatterns:
            if re.match(pattern, plate):
                return getUKDetails(plate)
    return currentCarDetails

def getManxDetails(plate):
    session = requests.Session()

    base_url = "https://services.gov.im/service/VehicleSearch"

    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36",
        "Accept-Language": "en-US,en;q=0.9",
        "Accept-Encoding": "gzip, deflate, br",
        "Connection": "keep-alive",
        "Upgrade-Insecure-Requests": "1",
        "Referer": base_url,
    }

    response = session.get(base_url, headers=headers)

    if response.status_code != 200:
        print(f"Error {response.status_code}: No token")
        return None

    soup = BeautifulSoup(response.text, "html.parser")
    input = soup.find("input", {"name": "__RequestVerificationToken"})
    
    if not input:
        print("Couldn't find verif token.")
        return None

    verification_token = input["value"]

    form_data = {
        "RegMarkNo": plate,
        "__RequestVerificationToken": verification_token,
    }

    response = session.post(base_url, headers=headers, data=form_data)

    if response.status_code != 200:
        print(f"error {response.status_code}")
        return None

    soup = BeautifulSoup(response.text, "html.parser")
    
    vehicleInfo = {
        "reg": plate,
        "make": "Unknown",
        "model": "Unknown",
        "taxValid": False,
        "motValid": False,
        "manxVehicleMotExempt": True,
        "vehicleImage": "",
    }

    table = soup.find("table", class_="table table-bordered")
    
    if table:
        for row in table.find_all("tr"):
            key = row.find("th").text.strip()
            value = row.find("td").text.strip()

            if key == "Make":
                vehicleInfo["make"] = value
            elif key == "Model":
                vehicleInfo["model"] = value
            elif key == "Status of Vehicle Licence (Tax)":
                vehicleInfo["taxValid"] = value == "Active"

    return vehicleInfo

def getUKDetails(plate):
    url = "https://driver-vehicle-licensing.api.gov.uk/vehicle-enquiry/v1/vehicles"
    apiKey = "key"
    headers = {
        "x-api-key": apiKey,
        "Content-Type": "application/json"
    }
    data = {"registrationNumber": plate}

    response = requests.post(url, json=data, headers=headers)

    if response.status_code != 200:
        print(response.json().get)
        return None

    vehicleData = response.json()

    vehicleInfo = {
        "reg": plate,
        "make": vehicleData.get("make", "Unknown"),
        "model": vehicleData.get("colour", "Unknown"),
        "taxValid": vehicleData.get("taxStatus", "").lower() == "taxed",
        "motValid": vehicleData.get("motStatus", "").lower() == "valid",
        "manxVehicleMotExempt": False,
        "vehicleImage": ""
    }

    return vehicleInfo
       
def captureImage():
    os.system("libcamera-jpeg -o newestImage.jpg -t 5000 --width 1920 --height 1080")
    print(f"Captured photo, analysing...")



if __name__ == "__main__":
    try:
        while True:
            captureImage()
            handleNewImage()
    except KeyboardInterrupt:
        print("killed")
        if os.path.exists("newestCapture.json"):
            os.remove("newestCapture.json")
            print("Deleted newestCapture.json")
