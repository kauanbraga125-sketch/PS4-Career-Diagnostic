"""Configure only Godot's Android tool paths; credentials stay in CI environment."""
import os
from pathlib import Path

settings = Path.home() / '.config/godot/editor_settings-4.5.tres'
sdk = os.environ.get('ANDROID_HOME', os.environ.get('ANDROID_SDK_ROOT', ''))
java = os.environ.get('JAVA_HOME', '')
assert sdk and java, 'Android SDK and Java 17 must be configured'
settings.parent.mkdir(parents=True, exist_ok=True)
settings.write_text('[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
                    f'export/android/android_sdk_path = "{sdk}"\n'
                    f'export/android/java_sdk_path = "{java}"\n')
