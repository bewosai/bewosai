"""Default Units every business starts with, so nobody has to build a unit
list from scratch before they can add their first product. Each business
still owns its own copy (Unit is business-scoped) and can freely add, edit,
or delete any of these — seeding just saves the initial setup work.

secondary_unit/conversion_factor follow Unit's own convention: 1 primary =
conversion_factor secondary (e.g. 1 Dozen = 12 Piece), used for billing in
whichever unit is more convenient for a given sale.
"""

DEFAULT_UNITS = [
    {"name": "Piece", "abbreviation": "pcs"},
    {"name": "Dozen", "abbreviation": "dz", "secondary_unit": "Piece", "secondary_abbreviation": "pcs", "conversion_factor": 12},
    {"name": "Box", "abbreviation": "box"},
    {"name": "Carton", "abbreviation": "ctn"},
    {"name": "Pack", "abbreviation": "pack"},
    {"name": "Kilogram", "abbreviation": "kg", "secondary_unit": "Gram", "secondary_abbreviation": "g", "conversion_factor": 1000},
    {"name": "Gram", "abbreviation": "g"},
    {"name": "Quintal", "abbreviation": "qtl", "secondary_unit": "Kilogram", "secondary_abbreviation": "kg", "conversion_factor": 100},
    {"name": "Ton", "abbreviation": "ton", "secondary_unit": "Kilogram", "secondary_abbreviation": "kg", "conversion_factor": 1000},
    {"name": "Liter", "abbreviation": "L", "secondary_unit": "Milliliter", "secondary_abbreviation": "ml", "conversion_factor": 1000},
    {"name": "Milliliter", "abbreviation": "ml"},
    {"name": "Meter", "abbreviation": "m", "secondary_unit": "Centimeter", "secondary_abbreviation": "cm", "conversion_factor": 100},
    {"name": "Centimeter", "abbreviation": "cm"},
    {"name": "Square Feet", "abbreviation": "sqft"},
    {"name": "Square Meter", "abbreviation": "sqm"},
    {"name": "Pair", "abbreviation": "pr", "secondary_unit": "Piece", "secondary_abbreviation": "pcs", "conversion_factor": 2},
    {"name": "Set", "abbreviation": "set"},
    {"name": "Gross", "abbreviation": "gr", "secondary_unit": "Piece", "secondary_abbreviation": "pcs", "conversion_factor": 144},
    {"name": "Bag", "abbreviation": "bag"},
    {"name": "Bottle", "abbreviation": "btl"},
    {"name": "Roll", "abbreviation": "roll"},
    {"name": "Ream", "abbreviation": "ream", "secondary_unit": "Sheet", "secondary_abbreviation": "sht", "conversion_factor": 500},
]


def seed_default_units(business):
    """Idempotent — safe to call for a business that already has some units
    (e.g. re-running a backfill), since it only fills in names that don't
    exist yet rather than overwriting anything the business has customized."""
    from .models import Unit

    existing = set(Unit.objects.filter(business=business).values_list("name", flat=True))
    to_create = [
        Unit(
            business=business,
            name=u["name"],
            abbreviation=u.get("abbreviation", ""),
            secondary_unit=u.get("secondary_unit", ""),
            secondary_abbreviation=u.get("secondary_abbreviation", ""),
            conversion_factor=u.get("conversion_factor"),
        )
        for u in DEFAULT_UNITS
        if u["name"] not in existing
    ]
    if to_create:
        Unit.objects.bulk_create(to_create)
