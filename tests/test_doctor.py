"""Unit tests for the diagnostic doctor subsystem."""
import unittest

from core.engine.doctor import Doctor


class TestDoctor(unittest.TestCase):
    def test_doctor_diagnostics_runs(self):
        doc = Doctor()
        doc.check_python()
        doc.check_os()
        doc.check_cgroups_v2()
        doc.check_state_db()

        python_check = next((item for item in doc.results if "Python" in item[0]), None)
        self.assertIsNotNone(python_check)
        self.assertTrue(python_check[1])


if __name__ == "__main__":
    unittest.main()
