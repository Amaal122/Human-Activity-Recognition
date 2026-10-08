# Human Activity Recognition on STM32U5

An in-progress edge-AI project for recognizing human activity from
three-axis accelerometer data. The target is the **B-U585I-IOT02A**
development board, based on the **STM32U585AII6Q / STM32U5** microcontroller.

The intended activity classes are:

- Stationary
- Walking
- Running

The project currently has two connected parts:

1. A Python/Jupyter workflow for preparing accelerometer data and training a
   classifier.
2. An STM32CubeIDE firmware project that initializes the board's
   ISM330DHCX motion sensor and streams accelerometer samples over serial.

> **Project status:** This project is not complete yet. The current firmware
> performs sensor acquisition and serial output, but the trained model has not
> yet been integrated into the STM32 firmware for real-time on-device
> classification.

## Inference output

The current inference workflow reports activity predictions in the serial
output, including the predicted class and its confidence scores:

![Example inference output](./inference-output.png)

## Repository layout

```text
.
├── Human-Activity-Recognition/
│   └── notebooks/
│       ├── Untitled.ipynb       # Dataset preparation and model experiments
│       ├── model.h5             # Generated Keras model (ignored by Git)
│       └── wisdm/                # Extracted WISDM dataset (ignored by Git)
├── CubeAi/
│   ├── CubeAi.ioc               # STM32CubeMX configuration
│   ├── Core/                     # STM32 application source and headers
│   ├── Drivers/                 # STM32 HAL, CMSIS, board and sensor drivers
│   └── CubeAi/                  # Second CubeIDE project copy/generated tree
└── realtime_visualization.m      # MATLAB serial plotter for X/Y/Z samples
```

The repository currently contains two STM32CubeIDE project trees under
`CubeAi/`: one at the directory root and another under `CubeAi/CubeAi/`.
They contain overlapping generated files and should be consolidated or clearly
identified before the firmware project is finalized.

## Machine-learning workflow

The notebook uses the **WISDM activity recognition dataset v1.1**. It:

1. Extracts the dataset archive.
2. Parses the raw records into user, activity, timestamp, and X/Y/Z columns.
3. Maps the original labels:
   - `Sitting` and `Standing` -> `Stationary`
   - `Walking` -> `Walking`
   - `Jogging` -> `Running`
4. Converts acceleration from m/s² to approximately mg.
5. Builds recordings of 300 samples per segment.
6. Generates one-second frames of 20 samples with a 50% overlap.
7. Normalizes the frame values by dividing by `2000`.
8. Trains and evaluates a TensorFlow/Keras Conv1D model.
9. Saves the trained model as `model.h5`.

The current neural-network architecture is:

```text
Input:       20 samples x 3 axes
Conv1D:      16 filters, kernel size 3, ReLU
Conv1D:       8 filters, kernel size 3, ReLU
Dropout:     0.5
Flatten
Dense:       64 units, ReLU
Output:       3 units, softmax
```

The notebook also contains a Random Forest experiment using summary features
(mean, standard deviation, minimum, maximum, and acceleration magnitude) while
testing different decimation rates and frame durations.

### Important preprocessing alignment issue

The notebook experiments use an original dataset rate of **20 Hz** and one
second frames of **20 samples**. The current STM32 firmware configures the
ISM330DHCX accelerometer at **26 Hz**. These values must be made consistent
before deploying the model; otherwise the model will receive a different time
scale from the one used during training.

The model input also expects the same normalization and axis ordering used in
the notebook. The embedded preprocessing pipeline still needs to implement and
verify those steps.

## STM32U5 firmware

The firmware is generated/configured with STM32CubeMX and STM32CubeIDE. The
configuration targets:

- MCU: `STM32U585AIIxQ`
- Board: `B-U585I-IOT02A`
- Core: Arm Cortex-M33
- TrustZone: disabled in the current CubeMX configuration
- Sensor: ST ISM330DHCX accelerometer
- Sensor bus: I2C2
- Sensor data-ready interrupt: EXTI line 11
- Debug/serial output: USART1 at 115200 baud, 8-N-1

At startup, the firmware:

1. Initializes the HAL, clock, power, cache, communication peripherals, and
   board support code.
2. Registers the ISM330DHCX I2C bus functions.
3. Reads and validates the sensor `WHO_AM_I` identifier.
4. Configures the accelerometer at 26 Hz and ±4 g.
5. Enables the sensor data-ready interrupt.
6. Reads the X/Y/Z acceleration values when a sample-ready interrupt arrives.
7. Prints the three raw axis values as a comma-separated line over USART1.

The output format is equivalent to:

```text
   11,  -25, 1025
```

The firmware does **not** currently:

- Buffer a complete inference window.
- Apply the notebook's normalization in embedded code.
- Run the TensorFlow/Keras model on the MCU.
- Produce `Stationary`, `Walking`, or `Running` predictions.
- Send a predicted class to the host.

## Real-time MATLAB visualization

[`realtime_visualization.m`](./realtime_visualization.m) opens a serial port,
reads three numeric values per line, and plots the X, Y, and Z axes in a
sliding window.

Before running it, update the COM port:

```matlab
portCOM = "COM23";
baudRate = 115200;
```

The baud rate must match the STM32 USART1 configuration. The MATLAB script is
currently a raw accelerometer viewer; it does not display activity
predictions.

## Getting started

### 1. Prepare the Python environment

Use a Python virtual environment outside the repository, or recreate the
environment locally. The repository's previous `Ai_model/` directory was a
virtual environment and is intentionally ignored.

Install the notebook dependencies:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install tensorflow numpy pandas matplotlib scikit-learn jupyter
```

### 2. Run the notebook

Open:

```text
Human-Activity-Recognition/notebooks/Untitled.ipynb
```

Run the cells in order. The notebook expects the WISDM archive to be available
in the notebook directory and extracts it into the local `wisdm/` directory.
The dataset and generated model are excluded by `.gitignore`.

### 3. Build the STM32 project

1. Install STM32CubeIDE and the STM32U5 device support packages.
2. Import the intended CubeIDE project under `CubeAi/`.
3. Confirm that the selected target is the B-U585I-IOT02A board and that the
   ISM330DHCX driver is present.
4. Build and flash the project to the board.
5. Open a serial terminal on the USART1 virtual COM port at 115200 baud.
6. Confirm that comma-separated X/Y/Z accelerometer samples are received.

The generated `Debug/` and `Release/` directories should not be committed.

## Recommended next steps

1. Select one STM32CubeIDE project tree and remove the duplicate project copy.
2. Decide whether the deployed model should use 20 Hz or change training to
   match the firmware's 26 Hz sampling rate.
3. Define the exact embedded preprocessing contract:
   frame length, hop length, axis order, units, scaling, and normalization.
4. Convert the Keras model to a microcontroller-compatible format, such as
   TensorFlow Lite for Microcontrollers or an STM32Cube.AI-generated network.
5. Generate and add the model inference sources and required runtime memory
   buffers.
6. Add a firmware ring buffer for one inference window.
7. Run inference only after a complete window is available.
8. Add confidence handling and temporal smoothing to avoid unstable labels.
9. Stream the predicted class and confidence to the host.
10. Validate predictions using recordings collected from the actual
    ISM330DHCX sensor and compare them with the WISDM-trained model.
11. Report reproducible metrics, including per-class precision, recall, F1,
    confusion matrix, latency, RAM usage, and flash usage.

## Known limitations

- The notebook is exploratory and contains multiple successive experiments.
- Some comments and implementation details may not yet be synchronized.
- The dataset sampling assumptions and firmware sampling rate differ.
- The current dataset selection is limited to a maximum of 40 recordings per
  class in the notebook workflow.
- No reproducible final model metrics are documented yet.
- The generated `model.h5` file is not a deployment-ready STM32 model.
- The firmware currently validates acquisition only, not end-to-end activity
  recognition.

## Dataset attribution

This project uses the WISDM activity prediction dataset v1.1. Please retain
the dataset's included `readme.txt` and cite:

> Jennifer R. Kwapisz, Gary M. Weiss, and Samuel A. Moore. “Activity
> Recognition using Cell Phone Accelerometers,” Proceedings of the Fourth
> International Workshop on Knowledge Discovery from Sensor Data (KDD-10),
> 2010.

See the dataset-provided documentation under
`Human-Activity-Recognition/notebooks/wisdm/WISDM_ar_v1.1/`.

## License and third-party components

The repository includes STMicroelectronics HAL, CMSIS, board-support, and
sensor-driver files. Keep their accompanying license files and follow the
licenses supplied with those components. The WISDM dataset has its own
redistribution and citation requirements.
