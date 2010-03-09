function presetTimeZoneFromBrowser() {
    tz = document.getElementById('timezone');
    var d = ((new Date().getTimezoneOffset()/60)*(-1)).toString().replace(/(.)([0-9])$/, "$10$2");
    var d2 = new Date().getTimezoneOffset();
    alert("D " + d + ' ' + d2);
    for(var i=0; i < tz.options.length; i++ ) {
        if( tz.options[i].text.match(new RegExp("..." +  d ))) {
            tz.selectedIndex = tz.options[i].index - 1;
            return;
        }
    }
    return NULL;
}
