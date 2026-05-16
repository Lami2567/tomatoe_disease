from pathlib import Path
from importlib import import_module

import numpy as np
from PIL import Image, ImageOps

MODEL_PATH = Path(__file__).resolve().parent.parent / 'models' / 'tomato_disease_model.tflite'

CLASS_NAMES = [
    'Tomato_Bacterial_spot',
    'Tomato_Early_blight',
    'Tomato_Late_blight',
    'Tomato_Leaf_Mold',
    'Tomato_Septoria_leaf_spot',
    'Tomato_Spider_mites_Two_spotted_spider_mite',
    'Tomato_Target_spot',
    'Tomato_Tomato_Yellow_Leaf_Curl_Virus',
    'Tomato_Tomato_mosaic_virus',
    'Tomato_healthy',
]

class TomatoDiseaseClassifier:
    def __init__(self):
        self._interpreter = None
        self._interpreter_class = None

    def _load_interpreter_class(self):
        if self._interpreter_class is not None:
            return self._interpreter_class
        try:
            import tensorflow as tf
        except ImportError:
            self._interpreter_class = import_module('tflite_runtime.interpreter').Interpreter
        else:
            self._interpreter_class = tf.lite.Interpreter
        return self._interpreter_class

    def _lazy_init(self):
        if self._interpreter is not None:
            return
        if not MODEL_PATH.exists():
            raise FileNotFoundError(
                f"Model file not found at {MODEL_PATH}. Place tomato_disease_model.tflite in backend/models/."
            )
        Interpreter = self._load_interpreter_class()
        self._interpreter = Interpreter(model_path=str(MODEL_PATH))
        self._interpreter.allocate_tensors()
        self.input_details = self._interpreter.get_input_details()
        self.output_details = self._interpreter.get_output_details()
        self.input_shape = tuple(int(v) for v in self.input_details[0]['shape'][1:3])
        self.input_dtype = self.input_details[0]['dtype']

    def preprocess(self, image_path):
        img = Image.open(image_path)
        img = ImageOps.exif_transpose(img).convert('RGB')
        img = img.resize((self.input_shape[1], self.input_shape[0]))
        img_array = np.array(img, dtype=np.float32)
        if self.input_dtype == np.float32:
            img_array = img_array / 255.0
        else:
            img_array = img_array.astype(self.input_dtype)
        img_array = np.expand_dims(img_array, axis=0)
        return img_array

    def predict(self, image_path):
        self._lazy_init()
        input_data = self.preprocess(image_path)
        self._interpreter.set_tensor(self.input_details[0]['index'], input_data)
        self._interpreter.invoke()
        output = self._interpreter.get_tensor(self.output_details[0]['index'])
        scores = np.squeeze(output).astype(np.float32)
        if scores.size != len(CLASS_NAMES):
            raise ValueError(f"Model returned {scores.size} scores, expected {len(CLASS_NAMES)}.")
        if scores.max() > 1.0 or scores.min() < 0.0:
            exp = np.exp(scores - np.max(scores))
            scores = exp / exp.sum()
        predicted_class_idx = int(np.argmax(scores))
        confidence = float(scores[predicted_class_idx])
        disease_class = CLASS_NAMES[predicted_class_idx]
        return disease_class, confidence

classifier = TomatoDiseaseClassifier()
