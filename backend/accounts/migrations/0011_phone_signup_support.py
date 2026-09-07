from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("accounts", "0010_business_mobile_trial_enabled_and_more"),
    ]

    operations = [
        migrations.AlterField(
            model_name="user",
            name="email",
            field=models.EmailField(blank=True, max_length=254, null=True, unique=True),
        ),
        migrations.RenameField(
            model_name="otpcode",
            old_name="email",
            new_name="identifier",
        ),
        migrations.AlterField(
            model_name="otpcode",
            name="identifier",
            field=models.CharField(max_length=254),
        ),
    ]
