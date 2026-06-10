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
    'Tomato_Bacterial_spot': (
        'Immediate Action: Prune and destroy heavily infected lower leaves during dry weather to reduce pathogen spread. '
        'Cultural Practices: Transition to drip or furrow irrigation to keep foliage completely dry; avoid working among wet plants. '
        'Treatments: Apply copper-based bactericides combined with mancozeb weekly starting at first sign of disease. '
        'Prevention: Practice a 2-3 year crop rotation away from solanaceous crops and use certified pathogen-free seeds.'
    ),
    'Tomato_Early_blight': (
        'Immediate Action: Snip off spotted lower foliage to improve airflow and halt upward progression. '
        'Cultural Practices: Spread a thick layer of organic mulch under plants to prevent soil-borne spores from splashing onto lower leaves. '
        'Treatments: Apply organic copper fungicides or chlorothalonil at the first sign of symptoms, repeating every 7-10 days. '
        'Prevention: Ensure wide spacing (at least 2 feet) between plants, rotate tomato plots annually, and clean up all plant debris at the end of the season.'
    ),
    'Tomato_Late_blight': (
        'Immediate Action: Act quickly as this disease spreads fast. Pull and bag heavily infected plants to prevent spore movement to neighboring crops. '
        'Cultural Practices: Water early in the day at the base of the plant to minimize leaf wetness. '
        'Treatments: Protect remaining healthy foliage by applying preventive fungicides containing chlorothalonil, copper, or mancozeb before rainy periods. '
        'Prevention: Avoid planting tomatoes near potatoes, select resistant cultivars (e.g., Mountain Merit, Defiant), and completely destroy volunteer tomato plants in spring.'
    ),
    'Tomato_Leaf_Mold': (
        'Immediate Action: Carefully pick off infected leaves showing yellow spots on the upper side and olive-green velvet growth underneath. '
        'Cultural Practices: Substantially increase ventilation and airflow using fans (especially in greenhouses); maintain relative humidity below 85%. '
        'Treatments: Apply protective fungicides such as copper soap or chlorothalonil if humidity cannot be controlled. '
        'Prevention: Space plants widely, prune lower suckers to open the canopy, and plant leaf mold resistant tomato varieties in the future.'
    ),
    'Tomato_Septoria_leaf_spot': (
        'Immediate Action: Prune off lower leaves with circular grey spots and black borders, washing tools in 10% bleach between cuts. '
        'Cultural Practices: Stake or cage tomato plants to elevate foliage off the ground; apply clean straw mulch around the base. '
        'Treatments: Spray with copper-based or chlorothalonil fungicides at the first sign of spotting, especially during warm, wet weather. '
        'Prevention: Rotate crops for at least 3 years away from nightshades (potatoes, eggplants, peppers) and keep the garden free of solanaceous weeds.'
    ),
    'Tomato_Spider_mites_Two_spotted_spider_mite': (
        'Immediate Action: Spray the undersides of leaves with a strong stream of water to dislodge mites and wash away fine webbing. '
        'Cultural Practices: Keep plants well-watered and mulched to reduce dry, dusty conditions which favor mite reproduction. '
        'Treatments: Apply insecticidal soaps, neem oil, or horticultural oils weekly, ensuring thorough coverage of leaf undersides. '
        'Prevention: Release beneficial predatory mites (e.g., Phytoseiulus persimilis) early in the season and avoid broad-spectrum chemical insecticides that kill natural predators.'
    ),
    'Tomato__Target_Spot': (
        'Immediate Action: Remove and destroy leaves displaying circular brown lesions with distinct concentric rings. '
        'Cultural Practices: Maximize air circulation within the plant canopy through pruning and staking; avoid overhead watering. '
        'Treatments: Apply copper-based fungicides, chlorothalonil, or mancozeb at the onset of warm, humid conditions. '
        'Prevention: Practice strict crop rotation, clear all crop residues immediately after harvest, and avoid planting new tomato blocks adjacent to older, infected ones.'
    ),
    'Tomato__Tomato_YellowLeaf__Curl_Virus': (
        'Immediate Action: Rogue (uproot and destroy) infected plants exhibiting stunted growth, cupped leaves, and yellow margins to prevent further spread. '
        'Cultural Practices: Use yellow sticky cards to monitor whitefly activity and cover young plants with fine insect netting. '
        'Treatments: Manage the whitefly vector using systemic insecticides (e.g., imidacloprid), insecticidal soaps, or horticultural oils. '
        'Prevention: Clean the field of weed hosts, plant only certified virus-resistant varieties (TYLCV resistant), and establish a crop-free period before planting.'
    ),
    'Tomato__Tomato_mosaic_virus': (
        'Immediate Action: Uproot and discard infected plants displaying mottled yellow-green leaf patterns and distorted growth. Do not compost them. '
        'Cultural Practices: Disinfect tools frequently in a 20% nonfat dry milk solution or 10% household bleach. Wash hands thoroughly with soap and water before handling healthy plants. '
        'Treatments: There is no chemical cure for viral infections; management relies entirely on prevention. '
        'Prevention: Choose certified mosaic-free seed, purchase resistant varieties (labeled T or TMV), and strictly prohibit smoking or handling of tobacco products near the greenhouse.'
    ),
    'Tomato_healthy': (
        'Assessment: Leaf appears healthy with no visible signs of pathogen infection or pest damage. '
        'Care Instructions: Maintain a consistent watering schedule targeting the root zone (avoid wetting leaves) and apply balanced fertilizer. '
        'Monitoring: Continue inspecting the undersides of lower leaves twice a week for spots, discoloration, or webbing. '
        'Cultural Practices: Maintain good plant spacing and pruning to keep air flowing freely through the canopy, preventing moisture buildup.'
    ),
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
