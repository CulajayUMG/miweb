const express = require('express');
const axios = require('axios');
const path = require('path');
const app = express();
const port = 3000;

// Establecer EJS como motor de plantillas
app.set('view engine', 'ejs');

// Definir la carpeta 'views' para las plantillas
app.set('views', path.join(__dirname, 'views'));

// Ruta para la página principal
app.get('/', async (req, res) => {
  try {
    const response = await axios.get('https://rickandmortyapi.com/api/character');
    //https://rickandmortyapi.com/api/character
    //https://rickandmortyapi.comcharacter
    const characters = response.data.results;
    res.render('index', { characters });
  } catch (error) {
    res.status(500).send('Error al obtener personajes');
  }
});

// Iniciar el servidor
app.listen(port, () => {
  console.log(`Servidor corriendo en http://localhost:${port}`);
});
