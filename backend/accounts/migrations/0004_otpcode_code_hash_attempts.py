from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('accounts', '0003_business_currency_business_fiscal_year_start_and_more'),
    ]

    operations = [
        migrations.RemoveField(
            model_name='otpcode',
            name='code',
        ),
        migrations.AddField(
            model_name='otpcode',
            name='code_hash',
            field=models.CharField(default='', max_length=128),
            preserve_default=False,
        ),
        migrations.AddField(
            model_name='otpcode',
            name='attempts',
            field=models.PositiveSmallIntegerField(default=0),
        ),
    ]
