from google.oauth2 import id_token
from google.auth.transport import requests
from django.contrib.auth.models import User
from rest_framework_simplejwt.tokens import RefreshToken
from django.conf import settings

def verify_google_token(id_token_str):
    try:
        client_id = getattr(settings, 'GOOGLE_OAUTH_CLIENT_ID', '')
        audience = client_id or None
        info = id_token.verify_oauth2_token(
            id_token_str,
            requests.Request(),
            audience
        )
        if info['iss'] not in ['accounts.google.com', 'https://accounts.google.com']:
            raise ValueError('Wrong issuer.')
        if not info.get('email_verified', False):
            raise ValueError('Google email is not verified.')
        return info
    except Exception:
        return None

def get_or_create_user(google_info):
    email = google_info['email']
    first_name = google_info.get('given_name', '')
    last_name = google_info.get('family_name', '')
    if not first_name and google_info.get('name'):
        parts = google_info['name'].split()
        first_name = parts[0]
        last_name = ' '.join(parts[1:])
    user, created = User.objects.get_or_create(
        username=email,
        defaults={
            'email': email,
            'first_name': first_name,
            'last_name': last_name
        }
    )
    changed = False
    if user.email != email:
        user.email = email
        changed = True
    if first_name and user.first_name != first_name:
        user.first_name = first_name
        changed = True
    if last_name and user.last_name != last_name:
        user.last_name = last_name
        changed = True
    if changed:
        user.save(update_fields=['email', 'first_name', 'last_name'])
    return user

def get_tokens_for_user(user):
    refresh = RefreshToken.for_user(user)
    return {
        'refresh': str(refresh),
        'access': str(refresh.access_token),
    }
