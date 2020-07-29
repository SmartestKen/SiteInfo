using System;
using System.Text.RegularExpressions;
using Fiddler;
using System.Text;
using System.IO;
using System.Collections.Generic;



namespace Fiddler {
	static class Base {

		internal static int size = 150;
		internal static LinkedList < string > [] hashedSites = new LinkedList < string > [size];
		internal static LinkedList < List<string[]> > [] detailSites = new LinkedList < List<string[]> > [size];









		internal static int getHash(string str) {
			byte[] asciiArr = Encoding.ASCII.GetBytes(str);
			int sum = 0;
			foreach(var value in asciiArr) {
				sum += value;
			}
			return sum % size;
		}


		internal static bool hostMatch(string ptn, string host){
			if (host.EndsWith('.' + realPtn) || string.Equals(host, realPtn))
			{
				var realPtn = ptn.Substring(1);
				if (host.EndsWith(realPtn))
					return true;
				else
					return false;
			}
			// support for regex
			else if (ptn.StartsWith("^"))
			{
				var ptnRegex = new Regex(ptn);
				return ptnRegex.Match(host).Success;
			}
			else
			{
				if (string.Equals(host, ptn))
					return true;
				else
					return false;
			}
		}


 




		internal static void inputSites() {

			try {

				string ruleStr = File.ReadAllText(@"c:\Users\k5shao\Downloads\siteFilter.txt", Encoding.UTF8);
				var newLinesRegex = new Regex(@"\r\n|\n|\r", RegexOptions.Singleline);
				var ruleList = newLinesRegex.Split(ruleStr);

				var i = 0; 

				while (i < ruleList.Length) {
					// index 0 the host, index 1 rule regex, index > 1 exception url
					
					var rule = ruleList[i];
					if (string.IsNullOrEmpty(rule)) {
						i += 1;
						FiddlerObject.log("nothing");
						continue;
					}
					if (rule.StartsWith("-----")) {
						FiddlerObject.log("end here");
						break;
					}



					string[] ruleInfo = rule.Split(' ');
					FiddlerObject.log(ruleInfo[1]);
					int hash = getHash(ruleInfo[0]);
					
					

					if (hashedSites[hash] == null) {
						hashedSites[hash] = new LinkedList < string > ();
						detailSites[hash] = new LinkedList < List<string[]> > ();
					}
					hashedSites[hash].AddLast(ruleInfo[1]);
					detailSites[hash].AddLast(new List<string[]>());
					
					
					
					while (true) 
					{
						i += 1;
						
						if (i == ruleList.Length)
							return;
						else
						{
							string subrule = ruleList[i];	
							if (subrule.StartsWith("a ") || subrule.StartsWith("b ")){
								string[] subruleInfo = subrule.Split(' ');
								detailSites[hash].Last.Value.Add(subruleInfo);
							}
							else
								break;

						}
					}	
						
				}

			} 
			
			
			catch(Exception e) {
				hashedSites = new LinkedList < string > [size];
				detailSites = new LinkedList < List<string[]> > [size];
				FiddlerObject.log("error in loading siteStr");
				FiddlerObject.log(e.ToString());
			}

		}










		// url part effective only when decrypt ability is on
		internal static bool isGoodUrl(string host, string url) {
			// return true;
			try {
				// only save last 2
				if (host.EndsWith(".edu")) {
					return true;
				}
				
				var hostTemp = host.Split('.');
				
				string domain = hostTemp[hostTemp.Length - 2] + "." + hostTemp[hostTemp.Length - 1];

				int hash = getHash(domain);
				if (hashedSites[hash] != null) {

			 		LinkedListNode < string > sh = hashedSites[hash].First;
					LinkedListNode < List<string[]> > sr = detailSites[hash].First;
					
					while (sh != null) {
						
						if (hostMatch(sh.Value, host)) 
						{

							List<string[]> subruleList = sr.Value;
							foreach (var rule in subruleList) {
								if (hostMatch(rule[1], host)) {
									FiddlerObject.log("ptn used   " + rule[1]);
									if (rule.Length > 2)
									{
										for (int i = 2; i < rule.Length; i++)
										{
											var linkptnRegex = new Regex(rule[i]);
											if (linkptnRegex.Match(url).Success)
												return !(string.Equals(rule[0], "a"));
										}
										
										return string.Equals(rule[0], "a");
									}
									else
										return string.Equals(rule[0], "a");
								}
							}
							// has entry but no applicable rule
							return true;
						}
						sh = sh.Next;
						sr = sr.Next;
					}

				}
				// no hash entry or no matched hash entry
				return false;
				
				
			} catch(Exception e) {
				FiddlerObject.log("Exception when checking good url");
				FiddlerObject.log(e.ToString());
				return false;
			}

		}
		
		
		
		
		
		
	}

















	public static class Handlers {


		public static void OnBeforeRequest(Session oSession) {
					
			// request part
			//oSession.bBufferResponse = false;
			//oSession["log-drop-request-body"] = "yes";
			//oSession["log-drop-response-body"] = "yes";
			if (!Base.isGoodUrl(oSession.hostname, oSession.url)) {
				FiddlerObject.log(oSession.hostname + ' ' + oSession.url + " 501");
				oSession.oRequest.FailSession(501, "Blocked", "Fiddler blocked");
			}
			else
				FiddlerObject.log(oSession.hostname + ' ' + oSession.url);

		}



		// main entry point
		public static void Main() {
			Base.inputSites();
		}

		
	}
}