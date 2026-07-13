#!/usr/bin/env python3
"""
Generate an interactive HTML viewer for eval results.

Reads eval outputs from a workspace directory and generates an HTML file
with tabs for viewing outputs and benchmark stats. Supports both interactive
server mode (Flask) and static HTML generation.

Usage:
    python generate_review.py <workspace-path> [--skill-name NAME] [--benchmark PATH] [--static OUTPUT_PATH]

Examples:
    # Interactive server (opens in browser)
    python generate_review.py ./eval-workspace --skill-name my-skill --benchmark ./benchmark.json

    # Static HTML file (for headless environments)
    python generate_review.py ./eval-workspace --static ./review.html
"""

import argparse
import json
import sys
import webbrowser
import mimetypes
from pathlib import Path
from datetime import datetime
from typing import Optional, Dict, List, Any
import base64

try:
    from flask import Flask, render_template_string, request, jsonify, send_file
    HAS_FLASK = True
except ImportError:
    HAS_FLASK = False


def load_eval_outputs(workspace_path: Path) -> Dict[str, Any]:
    """
    Load all eval outputs from workspace.

    Returns dict keyed by eval_id, containing with_skill and without_skill outputs.
    """
    evals = {}

    eval_dirs = sorted(workspace_path.glob("eval-*"))

    for eval_dir in eval_dirs:
        eval_id = eval_dir.name.split("-")[1] if "-" in eval_dir.name else "unknown"

        eval_data = {
            "eval_id": eval_id,
            "eval_name": eval_id,
            "with_skill": {},
            "without_skill": {}
        }

        # Try to load eval_metadata.json
        metadata_path = eval_dir / "eval_metadata.json"
        if metadata_path.exists():
            try:
                with open(metadata_path) as f:
                    meta = json.load(f)
                    eval_data["eval_name"] = meta.get("eval_name", eval_id)
                    eval_data["prompt"] = meta.get("prompt", "")
                    eval_data["assertions"] = meta.get("assertions", [])
            except json.JSONDecodeError:
                pass

        # Load with_skill outputs
        with_skill_dir = eval_dir / "with_skill" / "outputs"
        if with_skill_dir.exists():
            eval_data["with_skill"] = load_outputs_from_dir(with_skill_dir)

        # Load without_skill outputs
        without_skill_dir = eval_dir / "without_skill" / "outputs"
        if without_skill_dir.exists():
            eval_data["without_skill"] = load_outputs_from_dir(without_skill_dir)

        evals[eval_id] = eval_data

    return evals


def load_outputs_from_dir(output_dir: Path) -> Dict[str, Any]:
    """Load all files from an outputs directory."""
    outputs = {}

    if not output_dir.exists():
        return outputs

    for file_path in output_dir.rglob("*"):
        if not file_path.is_file():
            continue

        rel_path = str(file_path.relative_to(output_dir))

        # Try to read file content
        try:
            if file_path.suffix in [".json", ".txt", ".md", ".csv"]:
                with open(file_path, "r", encoding="utf-8") as f:
                    content = f.read()
                    outputs[rel_path] = {
                        "type": "text",
                        "content": content
                    }
            elif file_path.suffix in [".png", ".jpg", ".jpeg", ".gif", ".webp"]:
                with open(file_path, "rb") as f:
                    data = base64.b64encode(f.read()).decode("utf-8")
                    outputs[rel_path] = {
                        "type": "image",
                        "mime": mimetypes.guess_type(file_path)[0],
                        "data": data
                    }
            else:
                # Try to read as text, fallback to binary
                try:
                    with open(file_path, "r", encoding="utf-8") as f:
                        content = f.read()
                        outputs[rel_path] = {
                            "type": "text",
                            "content": content
                        }
                except UnicodeDecodeError:
                    outputs[rel_path] = {
                        "type": "binary",
                        "size": file_path.stat().st_size
                    }
        except Exception as e:
            outputs[rel_path] = {
                "type": "error",
                "error": str(e)
            }

    return outputs


def load_benchmark(benchmark_path: Optional[Path]) -> Dict[str, Any]:
    """Load benchmark.json if it exists."""
    if not benchmark_path or not benchmark_path.exists():
        return {}

    try:
        with open(benchmark_path) as f:
            return json.load(f)
    except json.JSONDecodeError as e:
        print(f"Warning: Failed to load benchmark.json: {e}")
        return {}


def generate_html(workspace_path: Path, evals: Dict, benchmark: Dict, skill_name: str = "", previous_workspace: Optional[Path] = None) -> str:
    """Generate the HTML content for the viewer."""

    html = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Eval Viewer - Skill Creator</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background: #f5f5f5;
            color: #333;
            line-height: 1.6;
        }

        .container {
            max-width: 1400px;
            margin: 0 auto;
            padding: 20px;
        }

        header {
            background: white;
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 20px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }

        h1 {
            font-size: 28px;
            margin-bottom: 10px;
        }

        .skill-info {
            font-size: 14px;
            color: #666;
            margin-top: 10px;
        }

        .tabs {
            display: flex;
            gap: 10px;
            margin: 20px 0;
            border-bottom: 2px solid #e0e0e0;
        }

        .tab-btn {
            padding: 10px 16px;
            border: none;
            background: transparent;
            cursor: pointer;
            font-size: 14px;
            font-weight: 500;
            border-bottom: 3px solid transparent;
            color: #666;
            transition: all 0.2s;
        }

        .tab-btn.active {
            color: #007acc;
            border-bottom-color: #007acc;
        }

        .tab-content {
            display: none;
        }

        .tab-content.active {
            display: block;
        }

        .outputs-tab {
            background: white;
            border-radius: 8px;
            padding: 20px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }

        .eval-nav {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 20px;
            padding-bottom: 10px;
            border-bottom: 1px solid #e0e0e0;
        }

        .eval-nav button {
            padding: 8px 12px;
            border: 1px solid #ddd;
            background: white;
            cursor: pointer;
            border-radius: 4px;
            font-size: 13px;
            transition: all 0.2s;
        }

        .eval-nav button:hover {
            background: #f0f0f0;
        }

        .eval-nav button:disabled {
            opacity: 0.5;
            cursor: not-allowed;
        }

        .eval-counter {
            font-weight: 600;
            color: #007acc;
        }

        .prompt-section {
            background: #f9f9f9;
            padding: 12px;
            border-radius: 4px;
            margin-bottom: 16px;
            border-left: 4px solid #007acc;
        }

        .prompt-label {
            font-weight: 600;
            font-size: 12px;
            color: #666;
            margin-bottom: 6px;
        }

        .prompt-text {
            font-size: 14px;
            line-height: 1.5;
        }

        .config-outputs {
            margin-bottom: 24px;
        }

        .config-title {
            font-weight: 600;
            font-size: 14px;
            padding: 8px;
            background: #f0f7ff;
            border-left: 3px solid #007acc;
            margin-bottom: 12px;
        }

        .output-file {
            margin-bottom: 16px;
            border: 1px solid #e0e0e0;
            border-radius: 4px;
            overflow: hidden;
        }

        .output-filename {
            background: #f5f5f5;
            padding: 8px 12px;
            font-family: 'Monaco', 'Menlo', monospace;
            font-size: 12px;
            border-bottom: 1px solid #e0e0e0;
        }

        .output-content {
            padding: 12px;
            background: white;
            max-height: 400px;
            overflow-y: auto;
        }

        .output-text {
            font-family: 'Monaco', 'Menlo', monospace;
            font-size: 12px;
            white-space: pre-wrap;
            word-break: break-word;
        }

        .output-image {
            max-width: 100%;
            border-radius: 4px;
        }

        .output-error {
            color: #d13438;
            font-size: 12px;
        }

        .output-binary {
            color: #999;
            font-size: 12px;
        }

        .feedback-section {
            margin-top: 20px;
            padding: 16px;
            background: #f0f7ff;
            border-radius: 4px;
        }

        .feedback-label {
            font-weight: 600;
            font-size: 13px;
            margin-bottom: 8px;
        }

        .feedback-textarea {
            width: 100%;
            padding: 8px;
            border: 1px solid #ccc;
            border-radius: 4px;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
            font-size: 13px;
            resize: vertical;
            min-height: 100px;
        }

        .feedback-textarea:focus {
            outline: none;
            border-color: #007acc;
            box-shadow: 0 0 0 3px rgba(0, 122, 204, 0.1);
        }

        .previous-output {
            margin-top: 16px;
            padding-top: 16px;
            border-top: 1px solid #e0e0e0;
        }

        .previous-output-header {
            font-weight: 600;
            font-size: 12px;
            color: #666;
            margin-bottom: 8px;
            cursor: pointer;
        }

        .benchmark-tab {
            background: white;
            border-radius: 8px;
            padding: 20px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }

        .stat-card {
            background: #f9f9f9;
            padding: 16px;
            border-radius: 4px;
            margin-bottom: 16px;
            border-left: 4px solid #007acc;
        }

        .stat-label {
            font-weight: 600;
            font-size: 13px;
            color: #666;
            margin-bottom: 4px;
        }

        .stat-value {
            font-size: 20px;
            font-weight: 600;
            color: #007acc;
        }

        .stat-delta {
            font-size: 13px;
            color: #999;
            margin-top: 4px;
        }

        table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 16px;
        }

        thead {
            background: #f5f5f5;
        }

        th, td {
            padding: 10px 12px;
            text-align: left;
            border-bottom: 1px solid #e0e0e0;
        }

        th {
            font-weight: 600;
            font-size: 13px;
        }

        tr:hover {
            background: #f9f9f9;
        }

        .controls {
            margin-bottom: 20px;
            display: flex;
            gap: 10px;
            flex-wrap: wrap;
        }

        button {
            padding: 10px 16px;
            border: none;
            border-radius: 6px;
            font-size: 14px;
            cursor: pointer;
            transition: background 0.2s;
            font-weight: 500;
        }

        .btn-primary {
            background: #007acc;
            color: white;
        }

        .btn-primary:hover {
            background: #005a9e;
        }

        .btn-secondary {
            background: #e0e0e0;
            color: #333;
        }

        .btn-secondary:hover {
            background: #d0d0d0;
        }

        footer {
            text-align: center;
            padding: 20px;
            color: #999;
            font-size: 12px;
        }

        @media (max-width: 768px) {
            .eval-nav {
                flex-direction: column;
                gap: 10px;
            }

            .eval-nav button {
                width: 100%;
            }

            .controls {
                flex-direction: column;
            }

            button {
                width: 100%;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>Eval Viewer</h1>
            <div class="skill-info">
                <strong>Skill:</strong> """ + skill_name + """<br>
                <strong>Evals:</strong> """ + str(len(evals)) + """ test case(s)
            </div>
        </header>

        <div class="tabs">
            <button class="tab-btn active" onclick="switchTab('outputs')">📊 Outputs</button>
            <button class="tab-btn" onclick="switchTab('benchmark')">📈 Benchmark</button>
        </div>

        <!-- OUTPUTS TAB -->
        <div id="outputs" class="tab-content active">
            <div class="outputs-tab">
                <div class="eval-nav">
                    <button onclick="prevEval()" id="prevBtn">← Previous</button>
                    <span class="eval-counter"><span id="currentEval">1</span> / <span id="totalEvals">""" + str(len(evals)) + """</span></span>
                    <button onclick="nextEval()" id="nextBtn">Next →</button>
                </div>

                <div id="evalContent">
                    <!-- Generated by JavaScript -->
                </div>

                <div class="controls" style="margin-top: 20px;">
                    <button class="btn-primary" onclick="submitReviews()">✓ Submit All Reviews</button>
                </div>
            </div>
        </div>

        <!-- BENCHMARK TAB -->
        <div id="benchmark" class="tab-content">
            <div class="benchmark-tab">
                <h2>Benchmark Results</h2>
                <div id="benchmarkContent">
                    <!-- Generated by JavaScript -->
                </div>
            </div>
        </div>

        <footer>
            <p>💡 Review outputs, add feedback, then submit. Arrow keys work for navigation.</p>
        </footer>
    </div>

    <script>
        const evals = """ + json.dumps(list(evals.values())) + """;
        let currentIdx = 0;
        let feedback = {};

        // Initialize feedback storage
        evals.forEach((e, i) => {
            feedback[i] = {
                'with_skill': '',
                'without_skill': ''
            };
        });

        function switchTab(tabName) {
            document.querySelectorAll('.tab-btn').forEach(btn => btn.classList.remove('active'));
            document.querySelectorAll('.tab-content').forEach(content => content.classList.remove('active'));

            event.target.classList.add('active');
            document.getElementById(tabName).classList.add('active');

            if (tabName === 'outputs') {
                renderEval();
            } else if (tabName === 'benchmark') {
                renderBenchmark();
            }
        }

        function renderEval() {
            const eval = evals[currentIdx];
            document.getElementById('currentEval').textContent = currentIdx + 1;

            let html = '';

            if (eval.prompt) {
                html += `<div class="prompt-section">
                    <div class="prompt-label">PROMPT</div>
                    <div class="prompt-text">${escapeHtml(eval.prompt)}</div>
                </div>`;
            }

            // with_skill outputs
            if (Object.keys(eval.with_skill).length > 0) {
                html += '<div class="config-outputs">';
                html += '<div class="config-title">✓ WITH SKILL</div>';
                html += renderOutputFiles(eval.with_skill);
                html += renderFeedbackBox('with_skill', eval);
                html += '</div>';
            }

            // without_skill outputs
            if (Object.keys(eval.without_skill).length > 0) {
                html += '<div class="config-outputs">';
                html += '<div class="config-title">✗ WITHOUT SKILL (BASELINE)</div>';
                html += renderOutputFiles(eval.without_skill);
                html += renderFeedbackBox('without_skill', eval);
                html += '</div>';
            }

            document.getElementById('evalContent').innerHTML = html;

            // Update nav buttons
            document.getElementById('prevBtn').disabled = currentIdx === 0;
            document.getElementById('nextBtn').disabled = currentIdx === evals.length - 1;

            // Attach feedback listeners
            document.querySelectorAll('.feedback-textarea').forEach(ta => {
                ta.addEventListener('input', (e) => {
                    const config = e.target.dataset.config;
                    feedback[currentIdx][config] = e.target.value;
                    // Auto-save to localStorage
                    localStorage.setItem(`feedback_${currentIdx}_${config}`, e.target.value);
                });

                // Restore from localStorage
                const saved = localStorage.getItem(`feedback_${currentIdx}_${ta.dataset.config}`);
                if (saved) {
                    ta.value = saved;
                    feedback[currentIdx][ta.dataset.config] = saved;
                }
            });
        }

        function renderOutputFiles(outputs) {
            let html = '';
            Object.entries(outputs).forEach(([filename, file]) => {
                html += '<div class="output-file">';
                html += `<div class="output-filename">${escapeHtml(filename)}</div>`;
                html += '<div class="output-content">';

                if (file.type === 'text') {
                    html += `<pre class="output-text">${escapeHtml(file.content)}</pre>`;
                } else if (file.type === 'image') {
                    html += `<img class="output-image" src="data:${file.mime};base64,${file.data}">`;
                } else if (file.type === 'error') {
                    html += `<div class="output-error">Error: ${escapeHtml(file.error)}</div>`;
                } else if (file.type === 'binary') {
                    html += `<div class="output-binary">Binary file (${file.size} bytes)</div>`;
                }

                html += '</div></div>';
            });
            return html;
        }

        function renderFeedbackBox(config, eval) {
            return `
                <div class="feedback-section">
                    <div class="feedback-label">📝 Feedback</div>
                    <textarea class="feedback-textarea" data-config="${config}" placeholder="Optional: any feedback or notes on this output..."></textarea>
                </div>
            `;
        }

        function renderBenchmark() {
            const benchmark = """ + json.dumps(benchmark) + """;

            if (!benchmark.run_summary) {
                document.getElementById('benchmarkContent').innerHTML = '<p>No benchmark data available.</p>';
                return;
            }

            let html = '<h3 style="margin-bottom: 16px;">Summary</h3>';

            const summary = benchmark.run_summary;
            Object.entries(summary).forEach(([config, stats]) => {
                if (config === 'delta') return;
                html += `
                    <div class="stat-card">
                        <div class="stat-label">${escapeHtml(config.replace(/_/g, ' ').toUpperCase())}</div>
                        <div style="display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 16px; margin-top: 12px;">
                            <div>
                                <div class="stat-label">Pass Rate</div>
                                <div class="stat-value">${(stats.pass_rate.mean * 100).toFixed(0)}%</div>
                                <div class="stat-delta">± ${(stats.pass_rate.stddev * 100).toFixed(0)}%</div>
                            </div>
                            <div>
                                <div class="stat-label">Time</div>
                                <div class="stat-value">${stats.time_seconds.mean.toFixed(1)}s</div>
                                <div class="stat-delta">± ${stats.time_seconds.stddev.toFixed(1)}s</div>
                            </div>
                            <div>
                                <div class="stat-label">Tokens</div>
                                <div class="stat-value">${Math.round(stats.tokens.mean)}</div>
                                <div class="stat-delta">± ${Math.round(stats.tokens.stddev)}</div>
                            </div>
                        </div>
                    </div>
                `;
            });

            if (summary.delta) {
                html += `
                    <div class="stat-card" style="border-left-color: #2ecc71;">
                        <div class="stat-label">DELTA (with_skill - without_skill)</div>
                        <div style="display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 16px; margin-top: 12px;">
                            <div>
                                <div class="stat-label">Pass Rate</div>
                                <div class="stat-value">${summary.delta.pass_rate}</div>
                            </div>
                            <div>
                                <div class="stat-label">Time</div>
                                <div class="stat-value">${summary.delta.time_seconds}s</div>
                            </div>
                            <div>
                                <div class="stat-label">Tokens</div>
                                <div class="stat-value">${summary.delta.tokens}</div>
                            </div>
                        </div>
                    </div>
                `;
            }

            document.getElementById('benchmarkContent').innerHTML = html;
        }

        function prevEval() {
            if (currentIdx > 0) {
                currentIdx--;
                renderEval();
            }
        }

        function nextEval() {
            if (currentIdx < evals.length - 1) {
                currentIdx++;
                renderEval();
            }
        }

        function submitReviews() {
            const feedbackData = {
                reviews: evals.map((e, i) => ({
                    eval_id: e.eval_id,
                    eval_name: e.eval_name,
                    feedback: {
                        with_skill: feedback[i]['with_skill'] || '',
                        without_skill: feedback[i]['without_skill'] || ''
                    },
                    timestamp: new Date().toISOString()
                })),
                status: 'complete',
                submitted_at: new Date().toISOString()
            };

            // Download feedback.json
            const dataStr = JSON.stringify(feedbackData, null, 2);
            const dataBlob = new Blob([dataStr], { type: 'application/json' });
            const url = URL.createObjectURL(dataBlob);
            const link = document.createElement('a');
            link.href = url;
            link.download = 'feedback.json';
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
            URL.revokeObjectURL(url);

            alert('Feedback saved to feedback.json. Copy it to the workspace directory.');
        }

        function escapeHtml(text) {
            const map = {
                '&': '&amp;',
                '<': '&lt;',
                '>': '&gt;',
                '"': '&quot;',
                "'": '&#039;'
            };
            return text.replace(/[&<>"']/g, m => map[m]);
        }

        // Arrow key navigation
        document.addEventListener('keydown', (e) => {
            if (e.key === 'ArrowLeft') prevEval();
            if (e.key === 'ArrowRight') nextEval();
        });

        // Initial render
        renderEval();
    </script>
</body>
</html>
"""

    return html


def main():
    parser = argparse.ArgumentParser(
        description="Generate an interactive HTML viewer for eval results"
    )
    parser.add_argument(
        "workspace",
        type=Path,
        help="Path to the eval workspace directory"
    )
    parser.add_argument(
        "--skill-name",
        default="<skill>",
        help="Name of the skill being evaluated"
    )
    parser.add_argument(
        "--benchmark",
        type=Path,
        help="Path to benchmark.json (optional)"
    )
    parser.add_argument(
        "--previous-workspace",
        type=Path,
        help="Path to previous iteration workspace (for comparison)"
    )
    parser.add_argument(
        "--static",
        type=Path,
        help="Write static HTML file instead of starting server"
    )

    args = parser.parse_args()

    if not args.workspace.exists():
        print(f"Error: Workspace not found: {args.workspace}")
        sys.exit(1)

    # Load data
    print(f"Loading evals from {args.workspace}...")
    evals = load_eval_outputs(args.workspace)

    if not evals:
        print(f"Warning: No evals found in {args.workspace}")
        evals = {}

    benchmark = load_benchmark(args.benchmark)

    print(f"Found {len(evals)} eval(s)")

    # Generate HTML
    html = generate_html(args.workspace, evals, benchmark, args.skill_name, args.previous_workspace)

    if args.static:
        # Write static HTML
        args.static.parent.mkdir(parents=True, exist_ok=True)
        with open(args.static, "w") as f:
            f.write(html)
        print(f"Generated: {args.static}")
    else:
        # Try to start server
        if not HAS_FLASK:
            print("Flask not available, writing static HTML instead...")
            output_file = args.workspace / "review.html"
            with open(output_file, "w") as f:
                f.write(html)
            print(f"Generated: {output_file}")
            print(f"Open in browser: {output_file}")
            return

        # Flask server
        app = Flask(__name__, static_folder=None)

        @app.route("/")
        def index():
            return html

        @app.route("/feedback", methods=["POST"])
        def save_feedback():
            feedback = request.json
            feedback_path = args.workspace / "feedback.json"
            with open(feedback_path, "w") as f:
                json.dump(feedback, f, indent=2)
            return jsonify({"status": "ok", "path": str(feedback_path)})

        port = 8765
        print(f"Starting server on http://localhost:{port}")
        try:
            webbrowser.open(f"http://localhost:{port}")
        except:
            print(f"Open http://localhost:{port} in your browser")

        app.run(host="127.0.0.1", port=port, debug=False)


if __name__ == "__main__":
    main()
