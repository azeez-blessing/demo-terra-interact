attrib -r -s application
variable flow
git submodule update --init --recursive

Environment (dev1: tvar-->variable --->module)
 → Base Module (mod-base: variable ---> module) 
 → Application Module (ec2:  variable)

Infrastructure (network, compute, storage, databases, identity, security, monitoring, billing)
 |
 |
 |
 v
Application (servers[web, application(pm2 guinicorn), databases runtime])

 User (Human and Non-Human) (Iam )
