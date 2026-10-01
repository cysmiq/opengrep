"""Exercise the history gate with real Git graphs, without network access."""
import pathlib
import subprocess
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / "check-pr-history"


class HistoryTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.repo = pathlib.Path(self.tmp.name)
        self.git("init", "-q")
        self.git("config", "user.email", "history-test@example.invalid")
        self.git("config", "user.name", "History test")
        self.root = self.commit("root")
        self.git("branch", "upstream", self.root)
        self.base = self.commit("fork-fix")
        self.git("branch", "fork", self.base)
        self.git("checkout", "-q", "upstream")
        self.upstream = self.commit("upstream-change")
        self.git("checkout", "-q", "fork")

    def git(self, *args):
        return subprocess.check_output(
            ["git", *args], cwd=self.repo, text=True, stderr=subprocess.DEVNULL
        ).strip()

    def commit(self, name):
        (self.repo / name).write_text(name)
        self.git("add", name)
        self.git("commit", "-qm", name)
        return self.git("rev-parse", "HEAD")

    def check(self, upstream=""):
        return subprocess.run(
            ["bash", str(SCRIPT), self.base, "HEAD", upstream],
            cwd=self.repo, capture_output=True, text=True,
        ).returncode

    def test_linear_fork_commits(self):
        self.commit("feature")
        self.assertEqual(self.check(), 0)

    def test_verified_upstream_import(self):
        self.git("merge", "--no-ff", "-qm", "sync", "upstream")
        self.commit("gate-update")
        self.assertEqual(self.check(self.upstream), 0)
        self.assertNotEqual(self.check(), 0)

    def test_unverified_merge_is_rejected(self):
        self.git("checkout", "-qb", "unrelated", self.root)
        self.commit("unrelated-change")
        self.git("checkout", "-q", "fork")
        self.git("merge", "--no-ff", "-qm", "unrelated merge", "unrelated")
        self.assertNotEqual(self.check(self.upstream), 0)

    def test_import_after_fork_edits_is_rejected(self):
        self.commit("feature")
        self.git("merge", "--no-ff", "-qm", "late sync", "upstream")
        self.assertNotEqual(self.check(self.upstream), 0)

    def test_upstream_merge_history_is_accepted(self):
        self.git("checkout", "-qb", "upstream-feature", self.upstream)
        self.commit("upstream-feature-file")
        self.git("checkout", "-q", "upstream")
        self.commit("upstream-other-file")
        self.git("merge", "--no-ff", "-qm", "upstream PR", "upstream-feature")
        self.upstream = self.git("rev-parse", "HEAD")
        self.git("checkout", "-q", "fork")
        self.git("merge", "--no-ff", "-qm", "sync", "upstream")
        self.assertEqual(self.check(self.upstream), 0)

    def test_missing_base_is_rejected(self):
        self.git("checkout", "-q", "upstream")
        self.assertNotEqual(self.check(self.upstream), 0)


if __name__ == "__main__":
    unittest.main()
