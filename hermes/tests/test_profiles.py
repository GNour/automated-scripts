from hermes.profiles import is_plugin_allowed


def test_ops_profile_can_load_ops_scripts() -> None:
    assert is_plugin_allowed("ops", "ops_scripts") is True


def test_family_profile_cannot_load_ops_scripts() -> None:
    assert is_plugin_allowed("family", "ops_scripts") is False
