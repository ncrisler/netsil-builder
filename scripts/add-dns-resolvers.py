import os, sys

dns_resolvers = os.environ.get('DNS_RESOLVERS', '8.8.4.4, 8.8.8.8')
cluster_var_file = os.environ.get('CLUSTER_VAR_FILE', '/apps/build/vars/cluster.yml')

def main():
    with open(cluster_var_file, 'a') as f:
        resolvers = dns_resolvers.split(',')
        f.write('dns_resolvers:\n')
        for resolver in resolvers:
            r = resolver.strip()
            f.write('  - ' + r + '\n')

if __name__ == '__main__':
    main()
