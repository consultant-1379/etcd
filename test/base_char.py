""" from etcd import Client, Lock
from threading import Thread

class Connect_ETCD:

    etcd_ = Client(host='localhost', port = 2379)

    def __init__(self):
        self.__running=False
        self.downtime=0


    def start(self):
        if self.__running:
            utilprocs.log("Client is already running")
            return
        utilprocs.log("Starting deamon thread...")
        self.__running=True
        self.__worker=Thread(target=self.connect_etcd,name="connect_etcd")
        self.__worker.start()


    def stop(self):
        if not self.__running:
            utilprocs.log("Client is not started yet")
            return
        utilprocs.log("Stoping deamon thread...")
        self.__running=False
        self.__worker.join(30)
        if self.__worker.isAlive():
            utilprocs.log("Thread not terminated")


    def connect_etcd(self):
        #etcd_ = Client(hosts='eric-data-distributed-coordinator-ed-1', port = 4002
        while self.__running:
            try:
                start=time.time()
                data = self.etcd_.read("test").value
            except Exception as e:
                utilprocs.log(str(e))
                self.downtime+=time.time()-start
            time.sleep(1)
        #self.zk.stop()
        lock = etcd.Lock(etcd_, 'lock_etcd')
        lock.acquire(blocking=True, lock_ttl=None)
        utilprocs.log("Terminated gracefully") """