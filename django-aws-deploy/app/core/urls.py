from django.contrib import admin
from django.urls import path, include
from django_prometheus import exports

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', include('api.urls')),

    # Prometheus metrics — scraped by the Prometheus server on the private network.
    # Restrict access at the nginx level (allow only 127.0.0.1 / VPC CIDR).
    path('metrics', exports.ExportToDjangoView, name='prometheus-django-metrics'),
]
