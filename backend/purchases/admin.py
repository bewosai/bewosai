from django.contrib import admin
from .models import Purchase, PurchaseItem, PurchaseReturn

admin.site.register(Purchase)
admin.site.register(PurchaseItem)
admin.site.register(PurchaseReturn)
