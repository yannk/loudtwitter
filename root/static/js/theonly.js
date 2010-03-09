// this is an ugly piece of shit

// thanks ppk
function addEvent(obj,type,fn)
{
    if (obj.addEventListener)
        obj.addEventListener(type,fn,false);
    else if (obj.attachEvent)
        obj.attachEvent("on"+type,fn);
}

var ok;

function init()
{
    var W3CDOM = (document.createElement && document.getElementsByTagName);
    if (!W3CDOM) return;
    ok = 1;
}

init();

var replies;
var status_links;
var times;
var para;
var li;
var ft;

if (ok) {
    addEvent(window,"load", initSample);
}

function getElementsByClassName(className, tag, elm){
    var testClass = new RegExp("(^|\\\\s)" + className + "(\\\\s|$)");
    var tag = tag || "*";
    var elm = elm || document;
    var elements = (tag == "*" && elm.all)? elm.all : elm.getElementsByTagName(tag);
    var returnElements = [];
    var current;
    var length = elements.length;
    for(var i=0; i<length; i++){
        current = elements[i];
        if(testClass.test(current.className)){
            returnElements.push(current);
        }
    }
    return returnElements;
}


function initSample() {
    var form = document.getElementById("myForm");

    replies = getElementsByClassName('reply');
    status_links = getElementsByClassName('status-link');
    times = getElementsByClassName('time');
    para = document.getElementById('sample-p');
    li = document.getElementById('sample-li');

    var fhr  = document.getElementById('format_hide_replies');
    var fht  = document.getElementById('format_hide_time');
    var fhsl = document.getElementById('format_hide_status_link');
    ft = document.getElementById('formatter_type');

    // set initial values
    toggleVisFormatType();
    initVis(replies, fhr, "block");
    initVis(times, fht, "inline");
    initVis(status_links, fhsl, "inline");

    addEvent(fhr,  "click", toggleVisReplies);
    addEvent(fht,  "click", toggleVisTimes);
    addEvent(fhsl, "click", toggleVisStatusLinks);
    addEvent(ft,  "change", toggleVisFormatType);
}

function toggleVisReplies()     { toggleVis(replies, "block"); }
function toggleVisStatusLinks() { toggleVis(status_links, "inline"); }
function toggleVisTimes()       { toggleVis(times, "inline"); }


function toggleVisFormatType() {
    var current = ft.options[ft.selectedIndex].value;
    if ( current == "para" ) { 
        para.style.display = "block";
        li.style.display = "none";
    } else {
        li.style.display = "block";
        para.style.display = "none";
    }
}

function toggleVis(elts, style) {
    for (var i=0;i<elts.length;i++) {
        var toggled = elts[i].style.display == "none" ? style : "none";
        elts[i].style.display = toggled;
    }
}

function initVis(elts, controller, style) {
    var initValue =  controller.checked ? "none" : style;
    for (var i=0;i<elts.length;i++)
        elts[i].style.display == initValue;
}
