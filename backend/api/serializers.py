from rest_framework import serializers
from django.contrib.auth.models import User
from .models import ScanHistory

class UserSerializer(serializers.ModelSerializer):
    full_name = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'first_name', 'last_name', 'full_name']

    def get_full_name(self, obj):
        return obj.get_full_name() or obj.email.split('@')[0]

class ScanHistorySerializer(serializers.ModelSerializer):
    recommendation = serializers.SerializerMethodField()
    status = serializers.SerializerMethodField()
    image_url = serializers.SerializerMethodField()

    class Meta:
        model = ScanHistory
        fields = ['id', 'disease', 'confidence', 'status', 'recommendation', 'image', 'image_url', 'created_at']
        read_only_fields = ['id', 'created_at']

    def get_recommendation(self, obj):
        from .views import get_recommendation

        return get_recommendation(obj.disease)

    def get_status(self, obj):
        return 'healthy' if 'healthy' in obj.disease.lower() else 'infected'

    def get_image_url(self, obj):
        request = self.context.get('request')
        if not obj.image:
            return ''
        if request:
            return request.build_absolute_uri(obj.image.url)
        return obj.image.url

class GoogleAuthSerializer(serializers.Serializer):
    id_token = serializers.CharField()
