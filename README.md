
![Logo](https://raw.githubusercontent.com/ERevere/MobileANPR/refs/heads/Master/Frontend/MobileANPRSystem/MobileANPRSystem/Media/Logo-Extended.png)


## MobileANPR
MobileANPR is a personal use real-time vehicle monitoring system which alerts users to nearby potentially uninsured vehicles. The system comprises a processing device, web-server, and iOS app.
#### Project Components

- **Back-end Server**: Flask-powered HTTPS server that serves live vehicle data and dynamic connection strings.
- **Image Processing**: TensorFlow w/ MobileNetV2, CV2, and Fast-ALPR enable real-time image capture, preprocessing, and vehicle/registration recognition.
- **iOS App**: Securely communicates with the server to present the user interface and handle alerts.



## Features

- User-friendly UI/UX for use in a driving environment  

- Accessible design with both visual and audio indicators 


- Compliant with all UK/EU Data Protection Regulations

- Meets heuristic and accessibiltiy standards, such as ISO-9241-11, Apple’s Human Interface and Accessibility Guidelines, and WCAG 2.1.




## Setup

To generate self-signed certificates for secure local HTTPS communication:
```
chmod +x createcert.sh
./createcert.sh
```

This will produce:

- MobileANPR.local.key, MobileANPR.local.crt, MobileANPR.local.fullchain.crt

### Installing Certificates

**iOS**
- Email or Airdrop MobileANPR.local.crt to your iOS device.


- Tap it, go to Settings > General > About > Certificate Trust Settings, and enable full trust.

**MacOS**
- Double-click MobileANPR.local.crt.


- Set it to "Always Trust" under "System" or "Login" keychain.

### Running the Back-End
The back-end consists of two main components:
- **Install dependancies**
```
pip install -r requirements.txt
```

- **Start the Flask server**
```
python3 server.py
```

- **Start the image capture, preprocessing, and analysis section**

```
python3 captureProcess.py
```





## Acknowledgements

This project makes use of the following open-source tools and libraries:

- [Fast_ALPR](https://github.com/ankandrew/fast-alpr) – Lightweight ALPR
- [Flask](https://github.com/pallets/flask) – Web framework used for the HTTPS server  
- [BeautifulSoup](https://pypi.org/project/beautifulsoup4/) – HTML and XML parsing  
- [OpenCV](https://github.com/opencv/opencv) – Real-time computer vision library for image processing  
- [NumPy](https://github.com/numpy/numpy) –  Arrays and matrices  
- [TensorFlow](https://github.com/tensorflow/tensorflow) – Machine learning framework used
- [MobileNetV2](https://github.com/pytorch/vision/blob/main/torchvision/models/mobilenetv2.py) – Efficient neural network model
## Screenshots

![App Screenshot](https://i.imgur.com/GYe6XZh.png)

