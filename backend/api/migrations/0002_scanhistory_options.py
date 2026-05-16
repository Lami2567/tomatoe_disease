from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0001_initial'),
    ]

    operations = [
        migrations.AlterModelOptions(
            name='scanhistory',
            options={'ordering': ['-created_at'], 'verbose_name_plural': 'scan histories'},
        ),
    ]
