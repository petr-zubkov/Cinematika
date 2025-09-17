# Comprehensive Movie Filtering System for Cinematika

This document describes the advanced movie filtering system that has been implemented for the Cinematika movie streaming platform.

## Overview

The new filtering system provides users with a comprehensive and intuitive way to find movies based on multiple criteria. It supports both basic and advanced filtering options with real-time updates and a responsive design that works on both desktop and mobile devices.

## Features

### Basic Filters
- **Search**: Full-text search across movie titles
- **Type**: Filter by movie type (Movie, Series, Animated Series, Anime, TV Show)
- **Year Range**: Select movies from specific year ranges (From-To)

### Rating Filters
- **Kinopoisk Rating**: Filter by Kinopoisk rating range (0.0-10.0)
- **IMDB Rating**: Filter by IMDB rating range (0.0-10.0)

### Category Filters
- **Genres**: Multi-select filter for movie genres (Action, Comedy, Drama, etc.)
- **Countries**: Multi-select filter for production countries

### People Filters
- **Actors**: Filter by specific actors
- **Directors**: Filter by specific directors

### Advanced Filters
- **Quality**: Filter by video quality (HDRip, BDRip, WEB-DL, etc.)
- **Translation**: Filter by translation type (Professional, Amateur, Author)

## Technical Implementation

### Frontend Components

#### Mobile Version
- **File**: `themes/default/views/mobile/includes/filter.ejs`
- **Features**: Optimized for mobile devices with touch-friendly interface
- **Styling**: Mobile-first responsive design

#### Desktop Version
- **File**: `themes/default/views/desktop/filter.ejs`
- **Features**: Enhanced desktop experience with grid layout
- **Styling**: Modern glassmorphism design with smooth animations

### Backend API

#### New API Endpoints
- **GET /api/genres**: Returns list of available genres
- **GET /api/countries**: Returns list of available countries

#### API Response Format
```json
[
  {
    "id": 1,
    "name": "Action"
  },
  {
    "id": 2,
    "name": "Comedy"
  }
]
```

### Database Integration

The filtering system integrates with the existing Cinematika database through the `CP_get.movies()` function, which supports:

- Multiple filter criteria
- Range queries for ratings and years
- Multi-select for genres and countries
- Custom field filtering

### URL Structure

The system uses clean URL parameters to maintain filter state:

```
https://example.com/?q=action&type=movie&year=2020-2023&genre=Action&genre=Comedy&country=USA&kp_rating=70-90
```

#### Parameter Reference
- `q`: Search query
- `type`: Movie type
- `year`: Year range (from-to or single year)
- `genre`: Genre (can be multiple)
- `country`: Country (can be multiple)
- `actor`: Actor name
- `director`: Director name
- `kp_rating`: Kinopoisk rating range
- `imdb_rating`: IMDB rating range
- `custom.quality`: Video quality
- `custom.translate`: Translation type

## User Interface

### Filter Panel
- **Collapsible Design**: Filter panel can be toggled to save screen space
- **Organized Sections**: Filters are grouped into logical categories
- **Real-time Updates**: Filter state is immediately reflected in the UI

### Multi-select Components
- **Dynamic Loading**: Genres and countries are loaded dynamically from the database
- **Visual Feedback**: Selected items are clearly indicated
- **Counter Display**: Shows number of selected items when multiple are chosen

### Range Inputs
- **Number Inputs**: Precise control over rating and year ranges
- **Validation**: Ensures logical range values (e.g., "from" <= "to")
- **Flexible Ranges**: Supports single values and ranges

### Actions
- **Apply Filters**: Updates the movie list with selected criteria
- **Reset Filters**: Clears all filters and returns to default view
- **State Persistence**: Filter selections are maintained across page reloads

## Responsive Design

### Mobile Optimization
- **Touch-friendly**: Larger tap targets for mobile users
- **Compact Layout**: Efficient use of screen space
- **Smooth Animations**: Optimized for mobile performance

### Desktop Enhancement
- **Grid Layout**: Multiple filter columns for better space utilization
- **Hover Effects**: Enhanced visual feedback for mouse users
- **Advanced Styling**: Modern design with glassmorphism effects

## Browser Compatibility

The filtering system is compatible with all modern browsers:
- Chrome 60+
- Firefox 55+
- Safari 12+
- Edge 79+

## Performance Considerations

### Caching
- **API Responses**: Genre and country lists are cached
- **Filter State**: Client-side state management reduces server requests
- **Database Queries**: Optimized queries for filter combinations

### Loading Strategy
- **Lazy Loading**: Genre and country data loaded only when filter is opened
- **Progressive Enhancement**: Basic functionality works without JavaScript
- **Error Handling**: Graceful degradation for failed API requests

## Integration with Existing System

### Template Integration
- **Mobile**: Added to `themes/default/views/mobile/includes/header.ejs`
- **Desktop**: Added to `themes/default/views/desktop/includes/header.ejs`

### Database Compatibility
- **Sphinx Search**: Leverages existing Sphinx search capabilities
- **Existing Queries**: Extends current movie query functionality
- **Custom Fields**: Supports existing custom field system

### Configuration
- **No Configuration Required**: Works with existing Cinematika setup
- **Customizable**: Easily extendable for additional filter criteria
- **Language Support**: Integrated with existing localization system

## Future Enhancements

### Planned Features
- **Additional Filters**: Duration, language, subtitles
- **Save Filters**: Allow users to save favorite filter combinations
- **Filter Presets**: Quick access to popular filter combinations
- **Advanced Search**: Boolean operators and complex queries

### Extensibility
- **Plugin System**: Support for custom filter types
- **API Expansion**: Additional endpoints for filter data
- **UI Themes**: Multiple filter interface themes

## Usage Examples

### Basic Usage
1. Click the "Filter" button to open the filter panel
2. Select desired criteria (genre, year, rating, etc.)
3. Click "Apply Filters" to see results
4. Use "Reset" to clear all filters

### Advanced Usage
1. Combine multiple genres for broader results
2. Use rating ranges to find high-quality movies
3. Mix actor and director filters for specific searches
4. Combine year ranges with quality filters for recent releases

### Mobile Usage
1. Tap the filter icon to expand the panel
2. Use the multi-select dropdowns for genres and countries
3. Swipe to scroll through long lists of options
4. Tap outside the panel to close it

## Troubleshooting

### Common Issues
- **Filters not applying**: Check browser console for JavaScript errors
- **Slow loading**: Ensure API endpoints are accessible
- **Display issues**: Verify CSS files are loading correctly

### Debug Mode
Add `?debug=1` to URL to enable debug information:
- Filter state console logging
- API request/response logging
- Performance timing information

## Support

For issues or feature requests, please refer to the Cinematika documentation or create an issue in the project repository.

---

*This filtering system enhances the Cinematika platform with powerful, user-friendly movie discovery capabilities while maintaining compatibility with the existing codebase.*