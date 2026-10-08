import tensorflow as tf

H5_PATH = r"C:\Users\bougu\Human-Activity-Recognition\Human-Activity-Recognition\notebooks\model.h5"
TFLITE_PATH = r"C:\Users\bougu\Human-Activity-Recognition\Human-Activity-Recognition\notebooks\model.tflite"

# 1. Charger le modèle Keras
model = tf.keras.models.load_model(H5_PATH, compile=False)
model.summary()

# 2. Créer le convertisseur
converter = tf.lite.TFLiteConverter.from_keras_model(model)

# 3. Conversion simple (float32)
tflite_model = converter.convert()

# 4. Sauvegarder
with open(TFLITE_PATH, "wb") as f:
    f.write(tflite_model)

print(f"Modèle enregistré : {TFLITE_PATH} ({len(tflite_model) / 1024:.1f} Ko)")