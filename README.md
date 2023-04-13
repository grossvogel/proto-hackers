# ProtoHackers

Just fooling around with a couple of these challenges: https://protohackers.com/problems

More info and nice walkthroughs from Andrea Leopardi can be found here too: https://andrealeopardi.com/posts/protohackers-in-elixir/


## Process Interactions

```mermaid
sequenceDiagram
Client ->> EchoServer: connect to listen_socket
EchoServer ->> Supervisor: start task to handle connection
Supervisor ->> Task1: start and monitor child
activate Task1
Task1 ->> Client: reply
deactivate Task1
Client ->> EchoServer: connect to listen_socket
Client ->> EchoServer: connect to listen_socket
EchoServer ->> Supervisor: start task to handle connection
EchoServer ->> Supervisor: start task to handle connection
Supervisor ->> Task2: start and monitor child
activate Task2
Supervisor ->> Task3: start and monitor child
activate Task3
Task2 ->> Client: reply
deactivate Task2
Task3 ->> Client: reply
deactivate Task3

```
