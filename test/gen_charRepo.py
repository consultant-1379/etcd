import sys
import os
import json

def run(cmd, bail=True):
    print(f"RUNNING: {cmd}")
    res = os.system(cmd)
    if(res != 0):
        print(f"ERROR: Return value {res}")
        print(f"Command: {cmd}")
        if(bail):
            sys.exit(res)

def add_usecases(spans, template_path, output_path):
    with open(template_path, "r") as f:
        template = json.loads(f.read())
    template["ADP-Microservice-Characteristics-Report"]["results"] = []
    for span in spans:
        template["ADP-Microservice-Characteristics-Report"]["results"].append(
            {
                "use-case": span["name"],
                "description": span["tags"]["description"] if "description" in span["tags"] else f"TODO: description for UC {span['name']}",
                "labels": span["tags"]["labels"] if "labels" in span["tags"] else [],
                "duration": 0,
                "metrics": []
            }
        )
        if span["tags"]["phase"]=="upgrade" or span["tags"]["phase"]=="rollback":
            template["ADP-Microservice-Characteristics-Report"]["results"][-1]["traffic"] = span["tags"]["traffic"]
    with open(output_path, "w") as f:
        f.write(json.dumps(template, indent=2))

def update_report(span, namespace, in_path, cluster, regex):
    phase = span["tags"]["phase"] if "phase" in span["tags"] else "idle"
    cmd = f"""athena adp_char_report \\
                --use-case={span["name"]} \\
                --pods="{regex}" \\
                -f standard \\
                -n {namespace} \\
                -log INFO \\
                -e {span["end"]} \\
                -s {span["start"]} \\
                --pm-url pm.monitor.{cluster}.rnd.gic.ericsson.se \\
                --char-report {in_path} -o .
    """
    run(cmd)

def default(args, i, fallback):
    if (len(args) >= i+1):
        return args[i]
    else:
        return fallback

def main():
    test_dced_log = default(sys.argv, 1, "pod_logs/testdeploy.log")
    namespace = default(sys.argv, 2, "dced-characteristics-report")
    report_path = default(sys.argv, 3, "ci_config/characteristics-report.json")
    cluster = default(sys.argv, 4, "hoff102")
    regex = default(sys.argv, 5, "eric-data-distributed-coordinator-ed-.*")
    with open(test_dced_log, "r") as f:
        lines = [x.strip() for x in f.readlines() if "SPAN;" in x]
    spans = [json.loads(x.split(";", 1)[-1]) for x in lines]
    # testdeploy.log includes duplicate spans, so make them unique
    spans = list({x["name"]:x for x in spans}.values())
    intermediate_report = "char-report-intermediate.json"
    add_usecases(spans, report_path, intermediate_report)
    for span in spans:
        report_path = update_report(span, namespace, intermediate_report, cluster, regex)

if __name__ == "__main__":
    main()