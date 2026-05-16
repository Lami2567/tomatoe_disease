from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework import status
from .serializers import GoogleAuthSerializer, ScanHistorySerializer, UserSerializer
from .inference import classifier
from .models import ScanHistory
from .authentication import verify_google_token, get_or_create_user, get_tokens_for_user
from PIL import Image, UnidentifiedImageError
import tempfile
import os

RECOMMENDATIONS = {
    'Tomato_Bacterial_spot': 'Remove heavily infected leaves, avoid overhead watering, and use copper-based bactericides when advised locally.',
    'Tomato_Early_blight': 'Prune lower leaves, mulch soil splash zones, rotate crops, and apply a labeled fungicide if symptoms spread.',
    'Tomato_Late_blight': 'Remove infected foliage quickly, improve airflow, and apply a copper or chlorothalonil fungicide according to local guidance.',
    'Tomato_Leaf_Mold': 'Increase greenhouse ventilation, keep leaves dry, and remove affected leaves before applying a suitable fungicide.',
    'Tomato_Septoria_leaf_spot': 'Remove spotted leaves, keep soil from splashing, stake plants, and rotate away from nightshades next season.',
    'Tomato_Spider_mites_Two_spotted_spider_mite': 'Rinse leaf undersides, reduce plant stress, and use miticide or horticultural oil for severe infestations.',
    'Tomato_Target_spot': 'Remove infected debris, improve spacing, and use preventive fungicide where target spot is recurring.',
    'Tomato_Tomato_Yellow_Leaf_Curl_Virus': 'Control whiteflies, remove infected plants, and use resistant varieties for future planting.',
    'Tomato_Tomato_mosaic_virus': 'Remove infected plants, disinfect tools, wash hands after handling plants, and avoid tobacco contamination.',
    'Tomato_healthy': 'No disease detected. Keep a steady watering schedule, scout leaves twice a week, and maintain good airflow.',
}

class GoogleLoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = GoogleAuthSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        id_token_str = serializer.validated_data['id_token']
        google_info = verify_google_token(id_token_str)
        if not google_info:
            return Response({'error': 'Invalid Google token'}, status=status.HTTP_401_UNAUTHORIZED)
        user = get_or_create_user(google_info)
        tokens = get_tokens_for_user(user)
        user_data = UserSerializer(user).data
        return Response({
            'user': user_data,
            'tokens': tokens
        })

class UserProfileView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        serializer = UserSerializer(request.user)
        return Response(serializer.data)

class ScanUploadView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        image_file = request.FILES.get('image')
        if not image_file:
            return Response({'error': 'No image provided'}, status=status.HTTP_400_BAD_REQUEST)
        # Save uploaded file temporarily for inference
        suffix = os.path.splitext(image_file.name)[1] or '.jpg'
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
            for chunk in image_file.chunks():
                tmp.write(chunk)
            tmp_path = tmp.name
        # Run inference
        try:
            with Image.open(tmp_path) as img:
                img.verify()
            disease, confidence = classifier.predict(tmp_path)
        except (UnidentifiedImageError, OSError):
            return Response({'error': 'Upload must be an image'}, status=status.HTTP_400_BAD_REQUEST)
        except Exception as exc:
            return Response({'error': f'Inference failed: {exc}'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        finally:
            if os.path.exists(tmp_path):
                os.unlink(tmp_path)
        # Save scan
        image_file.seek(0)
        scan = ScanHistory.objects.create(
            user=request.user,
            image=image_file,
            disease=disease,
            confidence=confidence
        )
        scan_serializer = ScanHistorySerializer(scan, context={'request': request})
        recommendation = get_recommendation(disease)
        return Response({
            'class': disease,
            'confidence': confidence,
            'scan': scan_serializer.data,
            'recommendation': recommendation
        }, status=status.HTTP_201_CREATED)

class ScanHistoryView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        scans = ScanHistory.objects.filter(user=request.user).order_by('-created_at')
        disease = request.query_params.get('disease')
        if disease:
            scans = scans.filter(disease=disease)
        serializer = ScanHistorySerializer(scans, many=True, context={'request': request})
        return Response(serializer.data)

def get_recommendation(disease):
    return RECOMMENDATIONS.get(disease, 'Consult a local agricultural extension officer and isolate the affected plant while monitoring nearby leaves.')
