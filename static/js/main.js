var sections;

$(document).keypress(function( event ) {
//  console.log("KEY");
//  console.log(event.which);
  if ( event.which == 109 ) {
    event.preventDefault();
    $( sidenav ).toggleClass( "hide" );
    $( "div.main" ).toggleClass( "hide" );
  }
});

$(document).ready(function() {
    sections = $('div.main').find('div.section');
    highlight_section();
});
$(document).scroll(function() {
    if (sections) {
        highlight_section();
    }
});
var active = -1;
function highlight_section() {
    var wheight = $(window).height();
    var scrolltop = $(document).scrollTop() + wheight / 4;
    var found = false;
    for (var i = 0; i < sections.length; i++) {
        var section = sections[i];
        var name = section.id;
        var link = $('#link_'+name);
        if (found) {
          link.removeClass('scroll_active');
          continue;
        }

        var height = $(section).height();
        var top_offset = $(section).offset().top + height;
        if (scrolltop > top_offset) {
          link.removeClass('scroll_active');
        }
        else {
          if (active != i) {
              active = i;
              link.addClass('scroll_active');
//              if(history.pushState) {
//                  history.pushState(null, null, '#'+name);
//              }
//            else {
//                location.hash = '#'+name;
//            }
          }
          found = true;
        }
    }
}

