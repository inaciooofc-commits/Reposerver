document.addEventListener('DOMContentLoaded', function () {
    // Conecta ao namespace '/dashboard' do Socket.IO.
    // A URL é inferida, então só precisamos especificar o namespace.
    const socket = io("/dashboard");

    socket.on('connect', function() {
        console.log('Conectado ao servidor do dashboard via Socket.IO!');
    });

    // Elementos da página
    const addToQueueBtn = document.getElementById('add-to-queue');
    const youtubeUrlInput = document.getElementById('youtube-url');
    const songQueueUl = document.getElementById('song-queue');

    // Listener para o botão de adicionar à fila
    if (addToQueueBtn) {
        addToQueueBtn.addEventListener('click', function() {
            const url = youtubeUrlInput.value.trim();
            if (url) {
                console.log(`Enviando URL para a fila: ${url}`);
                socket.emit('add_to_queue', { url: url });
                youtubeUrlInput.value = ''; // Limpa o input
            } else {
                alert('Por favor, insira uma URL do YouTube.');
            }
        });
    }

    // Listener para atualizações da fila
    socket.on('queue_update', function(data) {
        console.log('Fila recebida:', data.queue);
        if (songQueueUl) {
            // Limpa a lista atual
            songQueueUl.innerHTML = '';

            // Adiciona cada música da fila à lista
            data.queue.forEach(song => {
                const li = document.createElement('li');
                li.textContent = song.title; // Exibe o título da música
                songQueueUl.appendChild(li);
            });
        }
    });

    socket.on('disconnect', function() {
        console.log('Desconectado do servidor do dashboard.');
    });
});
