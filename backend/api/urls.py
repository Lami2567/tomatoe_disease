from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from .views import GoogleLoginView, UserProfileView, ScanUploadView, ScanHistoryView

urlpatterns = [
    path('auth/login/google/', GoogleLoginView.as_view(), name='google_login_exact'),
    path('auth/google/', GoogleLoginView.as_view(), name='google_login'),
    path('auth/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('auth/user/', UserProfileView.as_view(), name='user_profile'),
    path('scan/upload/', ScanUploadView.as_view(), name='scan_upload'),
    path('scan/history/', ScanHistoryView.as_view(), name='scan_history'),
]
