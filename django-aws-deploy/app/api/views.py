from django.http import JsonResponse
from django.db import connection


def health_check(request):
    """Liveness probe — always returns 200 if the process is alive."""
    return JsonResponse({'status': 'ok'})


def readiness_check(request):
    """Readiness probe — verifies DB connectivity before accepting traffic."""
    try:
        connection.ensure_connection()
        return JsonResponse({'status': 'ready', 'db': 'ok'})
    except Exception as e:
        return JsonResponse({'status': 'not_ready', 'db': str(e)}, status=503)
