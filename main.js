function daysToGo () {
  var targetDate = new Date("September 9, 2015 12:45:00");
  var secsToGo = (targetDate - new Date()) / 1000;

  var str = '';

  var days = Math.floor(secsToGo / (60 * 60 * 24));
  if (days) {
    str += days + " day" + (days == 1 ? "" : "s");
    secsToGo -= days * 60 * 60 * 24;
  }

  var hours = Math.floor(secsToGo / (60 * 60));
  if (hours) {
    if (str.length) {
      str += ", ";
    }
    str += hours + " hour" + (hours == 1 ? "" : "s");
    secsToGo -= hours * 60 * 60;
  }

  var mins = Math.floor(secsToGo / 60);
  if (mins) {
    if (str.length) {
      str += ", ";
    }
    str += mins + " minute" + (mins == 1 ? "" : "s");
  } 

  return str;
}

function setCounter () {
  $('#counter').html( daysToGo() );
}

$( document ).ready(function() {
 setCounter();
});
