from pathlib import Path
from importlib import import_module

import numpy as np
from PIL import Image, ImageOps

MODEL_PATH = Path(__file__).resolve().parent.parent / 'models' / 'tomato_disease_model.tflite'
LABELS_PATH = MODEL_PATH.with_name('labels.txt')

DEFAULT_CLASS_NAMES = [
    'Tomato_Bacterial_spot',
    'Tomato_Early_blight',
    'Tomato_Late_blight',
    'Tomato_Leaf_Mold',
    'Tomato_Septoria_leaf_spot',
    'Tomato_Spider_mites_Two_spotted_spider_mite',
    'Tomato__Target_Spot',
    'Tomato__Tomato_YellowLeaf__Curl_Virus',
    'Tomato__Tomato_mosaic_virus',
    'Tomato_healthy',
]


def load_class_names():
    if not LABELS_PATH.exists():
        return DEFAULT_CLASS_NAMES
    labels = [
        line.strip()
        for line in LABELS_PATH.read_text(encoding='utf-8').splitlines()
        if line.strip()
    ]
    return labels or DEFAULT_CLASS_NAMES


CLASS_NAMES = load_class_names()

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
        output_size = int(np.prod(self.output_details[0]['shape']))
        if output_size != len(CLASS_NAMES):
            raise ValueError(
                f"Model returns {output_size} classes, but labels file contains {len(CLASS_NAMES)} labels."
            )

    def _quantization(self, tensor_details):
        params = tensor_details.get('quantization_parameters') or {}
        scales = params.get('scales')
        zero_points = params.get('zero_points')
        if scales is not None and zero_points is not None and len(scales) > 0 and float(scales[0]) > 0:
            return float(scales[0]), int(zero_points[0])
        scale, zero_point = tensor_details.get('quantization', (0.0, 0))
        if scale:
            return float(scale), int(zero_point)
        return None

    def preprocess(self, image_path):
        img = Image.open(image_path)
        img = ImageOps.exif_transpose(img).convert('RGB')
        img = img.resize((self.input_shape[1], self.input_shape[0]), Image.Resampling.BILINEAR)
        img_array = np.array(img, dtype=np.float32)
        if self.input_dtype == np.float32:
            pass
        else:
            quantization = self._quantization(self.input_details[0])
            if quantization and np.issubdtype(self.input_dtype, np.integer):
                scale, zero_point = quantization
                img_array = np.round((img_array / scale) + zero_point)
                info = np.iinfo(self.input_dtype)
                img_array = np.clip(img_array, info.min, info.max)
            img_array = img_array.astype(self.input_dtype)
        img_array = np.expand_dims(img_array, axis=0)
        return img_array

    def _postprocess(self, output):
        scores = np.squeeze(output).astype(np.float32)
        quantization = self._quantization(self.output_details[0])
        if quantization:
            scale, zero_point = quantization
            scores = (scores - zero_point) * scale
        if scores.size != len(CLASS_NAMES):
            raise ValueError(f"Model returned {scores.size} scores, expected {len(CLASS_NAMES)}.")
        total = float(scores.sum())
        if scores.min() >= 0.0 and scores.max() <= 1.0 and np.isclose(total, 1.0, atol=0.05):
            return scores
        exp = np.exp(scores - np.max(scores))
        return exp / exp.sum()

    def predict(self, image_path):
        self._lazy_init()
        input_data = self.preprocess(image_path)
        self._interpreter.set_tensor(self.input_details[0]['index'], input_data)
        self._interpreter.invoke()
        output = self._interpreter.get_tensor(self.output_details[0]['index'])
        scores = self._postprocess(output)
        predicted_class_idx = int(np.argmax(scores))
        confidence = float(scores[predicted_class_idx])
        disease_class = CLASS_NAMES[predicted_class_idx]
        return disease_class, confidence

classifier = TomatoDiseaseClassifier()
