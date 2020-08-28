from mitmproxy import http
import re
import socket

# change to 150
size = 150
siteFilter = [None] * size

logToggle = 1
try:
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    # sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.connect(("127.0.0.1", 5080))
except Exception as e:
    logToggle = 0




def getHash(str):
    return sum(bytearray(str, "utf8")) % size


def readSites():
    global siteFilter

    try:
        with open('/temp/siteFilter.txt', 'r') as f:
            rawList = f.read()
        rawList = rawList.splitlines()



        for rawLine in rawList:

            rawLine = rawLine.strip()

            # line contains nothing
            if not rawLine or rawLine.startswith("#"):
                continue

            if rawLine.startswith("---"):
                # print("end here")
                break


            inputPieces = rawLine.split()


            # get the host
            if len(inputPieces[0]) == 1:
                isinputhost = True
                host = inputPieces[1]
                # print("host: ", host)
            else:
                isinputhost = False
                host = inputPieces[1].split("\/")[2].replace("\\","")
                # print("url host: ", host)

            # get the hash
            if host[0] == "*":
                hostSplitList = host[1:].split(".")
            else:
                hostSplitList = host.split(".")
            curHash = getHash(hostSplitList[-2] + "." + hostSplitList[-1])

            # print("curHash :", curHash)


            prevRule = None
            curRule = siteFilter[curHash]


            # input structure: [token host/url]
            # structure in tree: [token host/url next_matched next_unmatched]
            # node with url may only have not None unmatched branch
            while True:

                # print("curRule", curRule)
                if (curRule is None):
                    # assign the input node to the position
                    if prevRule is None:
                        siteFilter[curHash] = inputPieces + [None, None]
                    else:
                        prevRule[connection] = inputPieces + [None, None]
                    break



                if len(curRule[0]) == 1:
                    isnodehost = True
                    nodehost = curRule[1]
                else:
                    isnodehost = False
                    nodehost = curRule[1].split("\/")[2].replace("\\","")



                # equal
                if host == nodehost:
                    if isnodehost:
                        if isinputhost:
                            curRule[0] = inputPieces[0]
                            break
                        else:
                            branch = 2
                    else:
                        if isinputhost:
                            branch = -2
                        else:
                            # special: if url equal as well
                            if inputPieces[1] == curRule[1]:
                                curRule[0] = inputPieces[0]
                                break
                            else:
                                branch = 3
                # input is a subset of node
                elif ((nodehost[0] == '*') and
                      (host.endswith('.' + nodehost[1:]) or (host == nodehost[1:]))):
                    if isnodehost:
                        branch = 2
                    else:
                        branch = 3
                # input is a superset of node
                elif ((host[0] == '*') and
                      (nodehost.endswith('.' + host[1:]) or (nodehost == host[1:]))):
                    if isinputhost:
                        branch = -2
                    else:
                        branch = -3
                # disjoint (partially overlap is not possible)
                else:
                    branch = 3


                if branch > 0:
                    prevRule = curRule
                    # o-o- prevRule, connection, curRule, branch
                    # where branch is generated on the fly
                    connection = branch
                    curRule = curRule[branch]

                elif branch < 0:
                    if prevRule is None:
                        siteFilter[curHash] = inputPieces + [None, None]
                        siteFilter[curHash][-branch] = curRule
                    else:
                        prevRule[connection] = inputPieces + [None, None]
                        prevRule[connection][-branch] = curRule
                    break




        # print(siteFilter, file=open("/home/public/123.txt", "a"))



    except Exception as e:
        print("failure in readSites")
        print(e)
        siteFilter = [None] * size


def isGoodUrl(host, url):
    global siteFilter

    try:
        hostSplitList = host.split(".")
        curRule = siteFilter[getHash(hostSplitList[-2] + "." + hostSplitList[-1])]


        # default block everything, init token block by default
        # use token = 'a' if want to allow (say edu) sites by default
        if hostSplitList[-1] == 'edu':
            token = 'a'
        else:
            token = 'b'                                                                                          

        while (curRule != None):
            # host match
            if len(curRule[0]) == 1:
                if curRule[1][0] == '*':
                    realPtn = curRule[1][1:]
                    match_flag = (host.endswith('.' + realPtn) or (host == realPtn))
                else:
                    match_flag = (host == curRule[1])
            # url match
            else:
                if curRule[1][0] == '^':
                    match_flag = (re.match(curRule[1], url) != None)
                else:
                    match_flag = (url == curRule[1])

            # how to proceed based on match flag
            if match_flag:
                token = curRule[0][0]
                curRule = curRule[2]
            else:
                curRule = curRule[3]

        # final decision based on token
        return (token == "a")




    except Exception as e:
        print("failure in isGoodUrl")
        print(e)
        return False


def request(flow: http.HTTPFlow):
    global logToggle
    global sock

    host = flow.request.pretty_host
    url = flow.request.pretty_url

    prefix = "200 "

    if not isGoodUrl(host, url):
        flow.response = http.HTTPResponse.make(501)
        prefix = "501 "




    if logToggle:
        try:
            sock.send((prefix + host + " " + url).encode())
        except Exception as e:
            pass




readSites()
# print(siteFilter)

