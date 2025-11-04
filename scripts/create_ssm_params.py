#!/usr/bin/env python3
"""
Create SSM Parameter Store entries from the Parameters block in infra.yml.

Usage:
  python3 scripts/create_ssm_params.py --template infra.yml --prefix /santiago --region us-east-1 --profile default

This will create one SSM parameter per CloudFormation parameter using the Default value if present.
"""
import argparse
import subprocess
import sys
import yaml


# CloudFormation YAML loader that handles !Ref, !GetAtt, etc.
class CloudFormationLoader(yaml.SafeLoader):
    pass


def construct_ref(loader, node):
    """Handle !Ref tags"""
    return {'Ref': loader.construct_scalar(node)}


def construct_getatt(loader, node):
    """Handle !GetAtt tags"""
    if isinstance(node, yaml.ScalarNode):
        return {'Fn::GetAtt': loader.construct_scalar(node).split('.')}
    elif isinstance(node, yaml.SequenceNode):
        return {'Fn::GetAtt': loader.construct_sequence(node)}
    else:
        raise yaml.constructor.ConstructorError(
            None, None,
            f"expected a scalar or sequence node, but found {node.id}",
            node.start_mark)


def construct_sub(loader, node):
    """Handle !Sub tags"""
    return {'Fn::Sub': loader.construct_scalar(node)}


def construct_join(loader, node):
    """Handle !Join tags"""
    return {'Fn::Join': loader.construct_sequence(node)}


def construct_base64(loader, node):
    """Handle !Base64 tags"""
    return {'Fn::Base64': loader.construct_scalar(node)}


# Register constructors for CloudFormation intrinsic functions
CloudFormationLoader.add_constructor('!Ref', construct_ref)
CloudFormationLoader.add_constructor('!GetAtt', construct_getatt)
CloudFormationLoader.add_constructor('!Sub', construct_sub)
CloudFormationLoader.add_constructor('!Join', construct_join)
CloudFormationLoader.add_constructor('!Base64', construct_base64)


def run(cmd):
    print('+', ' '.join(cmd))
    r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    return r


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--template', default='infra.yml')
    p.add_argument('--prefix', default='/santiago')
    p.add_argument('--region', default='us-east-1')
    p.add_argument('--profile', default='default')
    args = p.parse_args()

    try:
        with open(args.template, 'r') as f:
            doc = yaml.load(f, Loader=CloudFormationLoader)
    except Exception as e:
        print('Failed to read template:', e)
        sys.exit(2)

    params = doc.get('Parameters', {}) if isinstance(doc, dict) else {}
    if not params:
        print('No Parameters found in', args.template)
        return

    for name, meta in params.items():
        default = meta.get('Default', '')
        
        # Skip parameters with empty default values
        if not default:
            print(f"Skipping SSM parameter {args.prefix}/{name} (no default value)")
            continue
            
        ssm_name = f"{args.prefix}/{name}"
        print(f"Creating SSM parameter {ssm_name} (value='{default}')")
        cmd = [
            'aws', 'ssm', 'put-parameter',
            '--name', ssm_name,
            '--value', str(default),
            '--type', 'String',
            '--overwrite',
            '--region', args.region,
            '--profile', args.profile,
        ]
        r = run(cmd)
        if r.returncode != 0:
            print('Error:', r.stderr.strip())
        else:
            print(r.stdout.strip())


if __name__ == '__main__':
    main()