"""Tests for scripts/benchmark.py."""

from unittest.mock import MagicMock, patch

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))

from benchmark import run_timed  # noqa: E402


def _mock_response(eval_count: int) -> MagicMock:
    mock = MagicMock()
    mock.json.return_value = {"eval_count": eval_count, "response": "test"}
    mock.raise_for_status = MagicMock()
    return mock


@patch("benchmark.requests.post")
@patch("benchmark.time.perf_counter", side_effect=[0.0, 2.0])
def test_run_timed_returns_tokens_per_second(mock_time: MagicMock, mock_post: MagicMock) -> None:
    mock_post.return_value = _mock_response(eval_count=50)

    tps = run_timed(model="llama3", prompt="Hello!", host="http://localhost:11434")

    assert tps == pytest.approx(25.0)


@patch("benchmark.requests.post")
@patch("benchmark.time.perf_counter", side_effect=[0.0, 1.0])
def test_run_timed_zero_eval_count(mock_time: MagicMock, mock_post: MagicMock) -> None:
    mock_post.return_value = _mock_response(eval_count=0)

    tps = run_timed(model="llama3", prompt="Hello!", host="http://localhost:11434")

    assert tps == 0.0


@patch("benchmark.requests.post")
@patch("benchmark.time.perf_counter", side_effect=[0.0, 4.0])
def test_run_timed_posts_to_correct_url(mock_time: MagicMock, mock_post: MagicMock) -> None:
    mock_post.return_value = _mock_response(eval_count=100)

    run_timed(model="mistral", prompt="Hi", host="http://localhost:11434/")

    args, kwargs = mock_post.call_args
    assert args[0] == "http://localhost:11434/api/generate"
    assert kwargs["json"]["model"] == "mistral"


import pytest  # noqa: E402 (needs to be available for approx)
