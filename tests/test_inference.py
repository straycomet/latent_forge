"""Smoke tests for scripts/run_inference.py."""

from unittest.mock import MagicMock, patch

import pytest

# Allow importing from the scripts directory
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))

from run_inference import run_inference  # noqa: E402


def _mock_response(text: str, status_code: int = 200) -> MagicMock:
    mock = MagicMock()
    mock.status_code = status_code
    mock.json.return_value = {"response": text}
    mock.raise_for_status = MagicMock()
    return mock


@patch("run_inference.requests.post")
def test_run_inference_returns_response_text(mock_post: MagicMock) -> None:
    expected = "Transformers are neural network architectures that use self-attention."
    mock_post.return_value = _mock_response(expected)

    result = run_inference(
        model="llama3",
        prompt="Explain transformers.",
        host="http://localhost:11434",
        temperature=0.7,
    )

    assert result == expected
    mock_post.assert_called_once()


@patch("run_inference.requests.post")
def test_run_inference_posts_to_correct_url(mock_post: MagicMock) -> None:
    mock_post.return_value = _mock_response("ok")

    run_inference(
        model="mistral",
        prompt="Hello",
        host="http://localhost:11434",
        temperature=0.5,
    )

    args, kwargs = mock_post.call_args
    assert args[0] == "http://localhost:11434/api/generate"
    assert kwargs["json"]["model"] == "mistral"
    assert kwargs["json"]["stream"] is False


@patch("run_inference.requests.post")
def test_run_inference_trims_trailing_slash_from_host(mock_post: MagicMock) -> None:
    mock_post.return_value = _mock_response("ok")

    run_inference(
        model="llama3",
        prompt="Hi",
        host="http://localhost:11434/",
        temperature=0.7,
    )

    args, _ = mock_post.call_args
    assert args[0] == "http://localhost:11434/api/generate"


@patch("run_inference.requests.post")
def test_run_inference_empty_response(mock_post: MagicMock) -> None:
    mock = MagicMock()
    mock.json.return_value = {}
    mock.raise_for_status = MagicMock()
    mock_post.return_value = mock

    result = run_inference(
        model="llama3",
        prompt="Hi",
        host="http://localhost:11434",
        temperature=0.7,
    )

    assert result == ""
