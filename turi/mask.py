import turicreate as tc
import os

ig02_path = '/Users/kupryakov/Documents/Develop/Diplom/detection/ig'

raw_sf = tc.image_analysis.load_images(ig02_path, recursive=True, random_order=True)

info = raw_sf['path'].apply(lambda path: os.path.basename(path).split('.')[:2])

info = info.unpack().rename({'X.0': 'name', 'X.1': 'type'})

raw_sf = raw_sf.add_columns(info)

raw_sf['label'] = raw_sf['name'].apply(lambda name: name.split('_')[0])

del raw_sf['path']

sf_images = raw_sf[raw_sf['type'] == 'image']
sf_masks = raw_sf[raw_sf['type'] == 'mask']

def mask_to_bbox_coordinates(img):
    import numpy as np
    mask = img.pixel_data
    if mask.max() == 0:
        return None
    x0, x1 = np.where(mask.max(0))[0][[0, -1]]
    y0, y1 = np.where(mask.max(1))[0][[0, -1]]

    return {'x': (x0 + x1) / 2, 'width': (x1 - x0),
            'y': (y0 + y1) / 2, 'height': (y1 - y0)}

sf_masks['coordinates'] = sf_masks['image'].apply(mask_to_bbox_coordinates)

sf_masks = sf_masks.dropna('coordinates')

sf_masks = sf_masks.pack_columns(['label', 'coordinates'],
                                 new_column_name='bbox', dtype=dict)

sf_annotations = sf_masks.groupby('name',
                                 {'annotations': tc.aggregate.CONCAT('bbox')})

sf = sf_images.join(sf_annotations, on='name', how='left')

sf['annotations'] = sf['annotations'].fillna([])

del sf['type']
sf.explore()
sf.save('ppl.sframe')