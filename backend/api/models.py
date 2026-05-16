from django.db import models
from django.contrib.auth.models import User

class ScanHistory(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='scans')
    image = models.ImageField(upload_to='scans/%Y/%m/%d/')
    disease = models.CharField(max_length=100)
    confidence = models.FloatField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name_plural = 'scan histories'

    def __str__(self):
        return f"{self.user.email} - {self.disease} - {self.created_at}"
