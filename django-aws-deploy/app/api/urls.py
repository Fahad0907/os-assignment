from django.urls import path
from . import views

urlpatterns = [
    path('health/', views.health_check, name='health'),
    path('ready/', views.readiness_check, name='ready'),
]
