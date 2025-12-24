const { extractors } = require('./index.js');

console.log('Registered domains:');
extractors.forEach(e => {
    if (e.domain.includes('ultimouomo')) {
        console.log(e.domain);
    }
});
