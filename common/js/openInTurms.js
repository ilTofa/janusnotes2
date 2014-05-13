javascript:(function() {
function se(d) {
    return d.selection ? d.selection.createRange().text : d.getSelection()
}
s = se(document);
for (i=0; i<frames.length && !s; i++) s = se(frames[i].document);
open('x-turms:' + encodeURIComponent(+ document.URL + '?' + document.title + '?' + s)).focus();
})();

OS X
javascript:(function(){open('x-turms:'+encodeURIComponent(document.URL)+'?'+encodeURIComponent(document.title)+'?'+encodeURIComponent(document.getSelection().toString())).focus();})();

iOS
javascript:window.location='x-turms:'+encodeURIComponent(document.URL)+'?'+encodeURIComponent(document.title)+'?'+encodeURIComponent(document.getSelection().toString())

Generic
javascript:window.location='x-turms:'+encodeURIComponent(document.URL)+'?'+encodeURIComponent(document.title)+'?'+encodeURIComponent(window.getSelection?window.getSelection().toString():document.selection.createRange().text)

<A HREF="javascript:(function(){var i,x; for (i=0;x=document.links[i];++i)x.style.color=[%22blue%22,%22red%22,%22orange%22][sim(x,location)]; function sim(a,b) { if (a.hostname!=b.hostname) return 0; if (fixPath(a.pathname)!=fixPath(b.pathname) || a.search!=b.search) return 1; return 2; } function fixPath(p){ p = (p.charAt(0)==%22/%22 ? %22%22 : %22/%22) + p;/*many browsers*/ p=p.split(%22?%22)[0];/*opera*/ return p; } })()" 
 title="This is a bookmarklet click to use, drag it to your links toolbar to use elsewhere"><span class="cyan">int/ext links</span></A>&quot;&nbsp;
(<font color="red">any browser</font>)